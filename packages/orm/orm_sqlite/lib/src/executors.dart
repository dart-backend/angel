/// The executors of SQLite, which share their transactions' bookkeeping.
library;

import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart' show CommonDatabase, ResultSet;
import 'package:sqlite_async/sqlite_async.dart';

import 'values.dart';

part 'orm_sqlite.dart';
part 'orm_sqlite_async.dart';
part 'scope.dart';

/// What the executors of SQLite share: the transactions of their database,
/// [_scopes], and the one of the executor, [_bound], if it is of one.
abstract class _SqliteExecutorBase<D extends Object> extends QueryExecutor {
  /// The [Logger] written to.
  final Logger logger;

  final D _database;

  /// The transactions and savepoints of [_database], which all its executors
  /// share.
  final _Scopes _scopes;

  /// The transaction or savepoint of this executor, if it is of one, of
  /// [transaction].
  final _Scope? _bound;

  static final Expando<_Scopes> _ofDatabase = Expando('SQLite transactions');

  _SqliteExecutorBase(this._database, this.logger, {required bool outsideWaits})
    : _scopes = _ofDatabase[_database] ??= _Scopes(outsideWaits: outsideWaits),
      _bound = null;

  _SqliteExecutorBase._of(_SqliteExecutorBase<D> executor, _Scope this._bound)
    : _database = executor._database,
      logger = executor.logger,
      _scopes = executor._scopes;

  @override
  Dialect get dialect => const SqliteDialect();

  /// The scope that a statement given now runs in.
  _Scope? get _scope => _scopes.current(_bound);

  /// The result of [f], given the scope that a statement given now runs in,
  /// [_scope]; or a failed future if it has none, as of an executor of a
  /// transaction that has ended, rather than an error thrown by the call.
  Future<R> _inScope<R>(Future<R> Function(_Scope? scope) f) =>
      Future.sync(() => f(_scope));

  /// Closes the database once the transactions on it, and the queries given
  /// outside them, have ended. Called again, it returns the same close.
  ///
  /// Throws a [StateError] in a transaction, which the close would wait for.
  ///
  /// A query or a transaction given outside a transaction once it is called
  /// throws a [StateError] at once, rather than running on the closed
  /// database; one given before it runs. If the database fails to close, the
  /// executor runs them again.
  Future<void> close() => _inScope((scope) {
    if (scope != null) {
      return Future.error(
        StateError('The database of a transaction is not closed in it.'),
      );
    }
    return _scopes.closed ??= _close();
  });

  Future<void> _close() async {
    _scopes.closing = true;
    try {
      await _scopes.whenIdle();
      await _closeDatabase();
    } catch (_) {
      _scopes
        ..closing = false
        ..closed = null;
      rethrow;
    }
  }

  Future<void> _closeDatabase();

  /// Runs [start], an operation of [scope], once [scope] may run a statement,
  /// as [_Scopes.whenReady], tracked by [scope], as [_Scopes.track].
  Future<R> _whenReady<R>(_Scope? scope, FutureOr<R> Function() start) =>
      _scopes.track(scope, () => _scopes.whenReady(scope, start));

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) {
    return _inScope(
      (parent) => _whenReady(parent, () async {
        var scope = _Scope(parent);
        _scopes.push(scope);
        try {
          return await _transaction(scope, f);
        } catch (e, st) {
          _logFailed(e, st);
          rethrow;
        } finally {
          _scopes.end(scope);
        }
      }),
    );
  }

  /// Runs [f] in [scope], which [transaction] has pushed: begins it, as a
  /// transaction or a savepoint of its parent, in the microtask of its call,
  /// and commits it, or rolls it back if [f] fails.
  Future<T> _transaction<T>(
    _Scope scope,
    FutureOr<T> Function(QueryExecutor) f,
  );

  /// Logs the error of a transaction: of its callback, or of its begin or
  /// commit. Fine, as the error is thrown to the caller, who handles it.
  void _logFailed(Object error, StackTrace stackTrace) => logger.fine(
    'The transaction failed, and is rolled back',
    error,
    stackTrace,
  );

  /// Runs [f] in [scope], and then waits for what was given in it and not
  /// awaited, as [_Scopes.drain]; and throws if SQLite rolled back the
  /// transaction, so that it is not committed.
  Future<T> _runCallback<T>(
    _Scope scope,
    FutureOr<T> Function(QueryExecutor) f,
    QueryExecutor executor,
  ) async {
    try {
      var result = await _scopes.runIn(
        scope,
        () => Future.sync(() => f(executor)),
      );
      await _scopes.drain(scope);
      if (scope.root.rolledBack) throw _rolledBack('it is not committed');
      return result;
    } catch (_) {
      // Before it is rolled back.
      await _scopes.drain(scope);
      rethrow;
    }
  }
}
