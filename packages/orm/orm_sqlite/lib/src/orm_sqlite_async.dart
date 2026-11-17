import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart' show ResultSet;
import 'package:sqlite_async/sqlite_async.dart';

import 'scope.dart';
import 'values.dart';

/// A [QueryExecutor] of a SQLite database of the `sqlite_async` package, on
/// SQLite 3.35 or later, which runs its statements on connections of their
/// own, in background isolates, so that they do not block the isolate that
/// gives them, as on a server.
///
/// `sqlite_async` writes on one connection, and reads on others, in WAL mode,
/// at the same time as it writes. A query outside a transaction that only
/// reads, a `SELECT`, runs on a connection that reads: it does not wait for a
/// transaction, and sees the rows as they were before it. Another waits for
/// the transaction, as `sqlite_async` writes one at a time.
///
/// A query given in a transaction, to the executor of its callback, or to any
/// executor of the database by the code of its callback, runs in it. Values
/// are stored as `SqliteExecutor` stores them.
class SqliteAsyncExecutor extends QueryExecutor {
  /// The [Logger] written to.
  final Logger logger;

  final SqliteConnection _database;

  /// The transaction and savepoints of [_database], which all its executors
  /// share.
  final Scopes _scopes;

  /// The transaction or savepoint of this executor, if it is of one, of
  /// [transaction].
  final Scope? _bound;

  static final Expando<Scopes> _databases = Expando(
    'SqliteAsyncExecutor database',
  );

  /// An executor of [database], such as a [SqliteDatabase], which pools its
  /// connections.
  SqliteAsyncExecutor(SqliteConnection database, {Logger? logger})
    : _database = database,
      logger = logger ?? Logger('SqliteAsyncExecutor'),
      _scopes = _databases[database] ??= Scopes(outsideWaits: false),
      _bound = null;

  SqliteAsyncExecutor._of(SqliteAsyncExecutor executor, Scope this._bound)
    : _database = executor._database,
      logger = executor.logger,
      _scopes = executor._scopes;

  @override
  Dialect get dialect => const SqliteDialect();

  /// The database of `sqlite_async`.
  SqliteConnection get database => _database;

  /// Closes the database once the transaction of this executor has ended.
  ///
  /// Throws a [StateError] in a transaction, which the close would wait for.
  Future<void> close() async {
    if (_scopes.current(_bound) != null) {
      throw StateError('The database of a transaction is not closed in it.');
    }
    for (var a = _scopes.active; a != null; a = _scopes.active) {
      await a.done.future;
    }
    await _database.close();
  }

  @override
  Future<List<List>> query(
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) async {
    var scope = _scopes.current(_bound);
    return _scopes.track(scope, () async {
      var insert = selectsInsertedRow(query, returningQuery);
      // Not while a savepoint begins in the scope, which `sqlite_async` locks
      // its context for; and no savepoint begins between the two statements
      // of an insert.
      for (
        var b = _scopes.blocker(scope);
        b != null;
        b = _scopes.blocker(scope)
      ) {
        await b;
      }
      var context = scope?.context as SqliteWriteContext?;
      Future<List<List>> run() async {
        if (!insert) {
          return _rows(await _statement(context, query, substitutionValues));
        }
        // The insert and the select of its row, of one connection, outside a
        // transaction as in one.
        return context != null
            ? _insertOn(context, query, returningQuery, substitutionValues)
            : _database.writeLock(
                (tx) =>
                    _insertOn(tx, query, returningQuery, substitutionValues),
              );
      }

      if (scope == null || !insert) return _checked(scope, context, run);
      var done = Completer<void>();
      scope.inserts.add(done.future);
      try {
        return await _checked(scope, context, run);
      } finally {
        scope.inserts.remove(done.future);
        done.complete();
      }
    });
  }

  /// Runs [statement], and marks the transaction as rolled back if it fails
  /// with an error after which SQLite rolled it back.
  Future<R> _checked<R>(
    Scope? scope,
    SqliteWriteContext? context,
    Future<R> Function() statement,
  ) async {
    try {
      return await statement();
    } catch (_) {
      if (scope != null && context != null) {
        try {
          if (await context.getAutoCommit()) _scopes.markRolledBack();
        } catch (_) {
          // The context has ended; so has the transaction.
        }
      }
      rethrow;
    }
  }

  /// The result of [sql]: on [context], or, outside a transaction, on a
  /// connection that reads, if it only reads, or else on the one that writes.
  ///
  /// It is given to `sqlite_async` in the microtask of its call, so that a
  /// savepoint cannot begin on [context] before it.
  Future<ResultSet> _statement(
    SqliteWriteContext? context,
    String sql,
    Map<String, dynamic> substitutionValues,
  ) {
    var (positional, params) = toPositional(sql, substitutionValues);
    logger.finest(() => 'SQL: $positional, parameters: $params');
    if (context != null) return context.execute(positional, params);
    return isSelect(positional)
        ? _database.getAll(positional, params)
        : _database.execute(positional, params);
  }

  Future<List<List>> _insertOn(
    SqliteWriteContext context,
    String query,
    String returningQuery,
    Map<String, dynamic> substitutionValues,
  ) async {
    var ids = await _statement(context, returningId(query), substitutionValues);
    if (ids.isEmpty) return [];
    return _rows(
      await _statement(
        context,
        returningQuery,
        withInsertId(substitutionValues, ids.rows.first.first),
      ),
    );
  }

  static List<List> _rows(ResultSet result) => result.rows;

  /// Runs [f] in a transaction of `sqlite_async`'s `writeTransaction`, which
  /// begins with `BEGIN IMMEDIATE`. A query outside it that writes waits for
  /// it to end; one that reads does not.
  ///
  /// A transaction in a transaction, as of an update or a delete of the ORM,
  /// is a savepoint of it, which is rolled back alone if [f] fails. The
  /// savepoints of a transaction run one at a time: a statement of the
  /// transaction, or another savepoint, given while one runs, waits for it to
  /// end.
  ///
  /// [f] is given an executor of the transaction, whose queries run in it from
  /// any zone; a query that the code of [f] gives to another executor of the
  /// database runs in it only in the zone of [f]. One that writes, given
  /// elsewhere, waits for it to end, so [f] must not wait for it.
  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    var parent = _scopes.current(_bound);
    return _scopes.track(parent, () async {
      while (true) {
        var b = _scopes.blocker(parent);
        // Not between the two statements of an insert of the parent, whose
        // context `sqlite_async` locks while a savepoint runs.
        b ??= parent == null || parent.inserts.isEmpty
            ? null
            : Future.wait(List.of(parent.inserts));
        if (b == null) break;
        await b;
      }
      var scope = Scope(parent);
      _scopes.push(scope);
      try {
        Future<T> body(SqliteWriteContext tx) async {
          scope.context = tx;
          try {
            var result = await _scopes.runIn(
              scope,
              () => Future.sync(() => f(SqliteAsyncExecutor._of(this, scope))),
            );
            await _scopes.drain(scope);
            if (scope.root.rolledBack) {
              throw StateError(
                'SQLite rolled back the transaction after an error, so it is '
                'not committed.',
              );
            }
            return result;
          } catch (e, st) {
            // Fine, as the error is thrown to the caller, who handles it.
            logger.fine('The transaction failed, and is rolled back', e, st);
            // Before `sqlite_async` rolls it back, and ends its context.
            await _scopes.drain(scope);
            rethrow;
          }
        }

        var parentContext = parent?.context as SqliteWriteContext?;
        // Called in this microtask, so that `sqlite_async` locks the context
        // of the parent before a statement of it is given.
        return await (parentContext == null
            ? _database.writeTransaction(body)
            : parentContext.writeTransaction(body));
      } finally {
        _scopes.end(scope);
      }
    });
  }
}
