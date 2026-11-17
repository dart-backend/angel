import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart';

import 'scope.dart';
import 'values.dart';

/// A [QueryExecutor] of a SQLite database of the `sqlite3` package, on SQLite
/// 3.35 or later, which runs its statements synchronously, on the isolate
/// that gives them. For a server, see `SqliteAsyncExecutor`, which does not
/// block it.
///
/// `sqlite3` runs a statement on one connection. While a transaction runs, a
/// query given outside it waits for it to end; one given in it, to the
/// executor of its callback, or to any executor of the database by the code
/// of its callback, runs in it.
///
/// Values are stored as SQLite stores them: a `bool` as `0` or `1`, a
/// [DateTime] as UTC text (`2024-03-10 12:34:56.000000Z`), which sorts and
/// compares in time order, a `List<int>`, such as a `Uint8List`, as a BLOB,
/// and another [List] or a [Map] as JSON text, in which a [DateTime] is text
/// as it is stored.
class SqliteExecutor extends QueryExecutor {
  /// The [Logger] written to.
  final Logger logger;

  final CommonDatabase _database;

  /// The transaction and savepoints of [_database], which all its executors
  /// share.
  final Scopes _scopes;

  /// The transaction or savepoint of this executor, if it is of one, of
  /// [transaction].
  final Scope? _bound;

  static final Expando<Scopes> _databases = Expando('SqliteExecutor database');

  SqliteExecutor(CommonDatabase database, {Logger? logger})
    : _database = database,
      logger = logger ?? Logger('SqliteExecutor'),
      _scopes = _databases[database] ??= Scopes(outsideWaits: true),
      _bound = null;

  SqliteExecutor._of(SqliteExecutor executor, Scope this._bound)
    : _database = executor._database,
      logger = executor.logger,
      _scopes = executor._scopes;

  @override
  Dialect get dialect => const SqliteDialect();

  /// The database of `sqlite3`.
  CommonDatabase get database => _database;

  /// Closes the database once the transaction that holds it has ended.
  ///
  /// Throws a [StateError] in a transaction, which the close would wait for.
  Future<void> close() async {
    if (_scopes.current(_bound) != null) {
      throw StateError('The database of a transaction is not closed in it.');
    }
    for (var b = _scopes.blocker(null); b != null; b = _scopes.blocker(null)) {
      await b;
    }
    _database.close();
  }

  /// Runs [f], a statement, and marks the transaction as rolled back if it
  /// fails with an error after which SQLite rolled it back.
  R _run<R>(R Function() f) {
    try {
      return f();
    } catch (_) {
      if (!_scopes.isEmpty && _database.autocommit) _scopes.markRolledBack();
      rethrow;
    }
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
      for (
        var b = _scopes.blocker(scope);
        b != null;
        b = _scopes.blocker(scope)
      ) {
        await b;
      }
      return _run(() {
        if (!selectsInsertedRow(query, returningQuery)) {
          return _select(query, substitutionValues);
        }
        var ids = _select(returningId(query), substitutionValues);
        if (ids.isEmpty) return <List>[];
        return _select(
          returningQuery,
          withInsertId(substitutionValues, ids.first.first),
        );
      });
    });
  }

  /// The rows of [sql], with its `@name` placeholders bound to
  /// [substitutionValues].
  List<List> _select(String sql, Map<String, dynamic> substitutionValues) {
    var (positional, params) = toPositional(sql, substitutionValues);
    logger.finest(() => 'SQL: $positional, parameters: $params');
    return _database.select(positional, params).rows;
  }

  /// Runs [f] in a transaction, which holds the database: a query given
  /// outside it waits for it to end.
  ///
  /// It begins with `BEGIN IMMEDIATE`, which takes the write lock of the
  /// database at once, so that another connection to the database file cannot
  /// write between its reads and its writes.
  ///
  /// A transaction in a transaction, as of an update or a delete of the ORM,
  /// is a savepoint of it, which is rolled back alone if [f] fails. The
  /// savepoints of a transaction run one at a time: a statement of the
  /// transaction, or another savepoint, given while one runs, waits for it to
  /// end.
  ///
  /// [f] is given an executor of the transaction, whose queries run in it from
  /// any zone; a query that the code of [f] gives to another executor of the
  /// database runs in it only in the zone of [f], and waits for it to end
  /// otherwise, as one outside it does.
  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    var parent = _scopes.current(_bound);
    return _scopes.track(parent, () async {
      for (
        var b = _scopes.blocker(parent);
        b != null;
        b = _scopes.blocker(parent)
      ) {
        await b;
      }
      var scope = Scope(parent);
      // Named by its depth, as one savepoint of each depth runs at a time.
      var savepoint = parent == null
          ? null
          : 'angel3_savepoint_${_depth(scope)}';
      _scopes.push(scope);
      try {
        return await _runIn(scope, savepoint, f);
      } finally {
        _scopes.end(scope);
      }
    });
  }

  /// The number of transactions and savepoints that [scope] is in.
  static int _depth(Scope scope) {
    var depth = 0;
    for (var s = scope.parent; s != null; s = s.parent) {
      depth++;
    }
    return depth;
  }

  Future<T> _runIn<T>(
    Scope scope,
    String? savepoint,
    FutureOr<T> Function(QueryExecutor) f,
  ) async {
    _run(
      () => _database.execute(
        savepoint == null ? 'BEGIN IMMEDIATE' : 'SAVEPOINT $savepoint',
      ),
    );
    try {
      var result = await _scopes.runIn(
        scope,
        () => Future.sync(() => f(SqliteExecutor._of(this, scope))),
      );
      await _scopes.drain(scope);
      if (scope.root.rolledBack) {
        throw StateError(
          'SQLite rolled back the transaction after an error, so it is not '
          'committed.',
        );
      }
      _run(
        () => _database.execute(
          savepoint == null ? 'COMMIT' : 'RELEASE $savepoint',
        ),
      );
      return result;
    } catch (e, st) {
      // Fine, as the error is thrown to the caller, who handles it.
      logger.fine('The transaction failed, and is rolled back', e, st);
      await _scopes.drain(scope);
      // Not if SQLite has rolled it back already, as of some errors, and its
      // savepoints with it.
      if (!scope.root.rolledBack && !_database.autocommit) {
        _database.execute(
          savepoint == null
              ? 'ROLLBACK'
              : 'ROLLBACK TO $savepoint; RELEASE $savepoint',
        );
      }
      rethrow;
    }
  }
}
