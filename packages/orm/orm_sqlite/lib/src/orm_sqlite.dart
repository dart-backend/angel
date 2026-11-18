part of 'executors.dart';

/// A [QueryExecutor] of a SQLite database of the `sqlite3` package, on SQLite
/// 3.35 or later, which runs its statements synchronously, on the isolate
/// that gives them. For a server, see [SqliteAsyncExecutor], which does not
/// block it.
///
/// `sqlite3` runs a statement on one connection. While a transaction runs, a
/// query given outside it, or another transaction, waits for it to end; one
/// given in it, to the executor of its callback, or to any executor of the
/// database by the code of its callback, runs in it.
///
/// Values are stored as SQLite stores them: a `bool` as `0` or `1`, a
/// [DateTime] as UTC text (`2024-03-10 12:34:56.000000Z`), which sorts and
/// compares in time order, a `Uint8List` as a BLOB, and a [List] or a [Map]
/// as JSON text, in which a [DateTime] is text as it is stored.
class SqliteExecutor extends _SqliteExecutorBase<CommonDatabase> {
  SqliteExecutor(CommonDatabase database, {Logger? logger})
    : super(database, logger ?? Logger('SqliteExecutor'), outsideWaits: true);

  SqliteExecutor._of(super.executor, super.bound) : super._of();

  /// The database of `sqlite3`.
  CommonDatabase get database => _database;

  @override
  Future<void> _closeDatabase() async => _database.close();

  /// Runs [f], a statement of [scope], and marks its transaction as rolled
  /// back if it fails with an error after which SQLite rolled it back.
  R _run<R>(_Scope? scope, R Function() f) {
    try {
      return f();
    } catch (_) {
      if (scope != null && _database.autocommit) scope.root.rolledBack = true;
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
  }) {
    return _inScope(
      (scope) => _whenReady(
        scope,
        () => _run(scope, () {
          if (!selectsInsertedRow(query, returningQuery)) {
            return _select(query, substitutionValues);
          }
          var ids = _select(returningId(query), substitutionValues);
          if (ids.isEmpty) return <List>[];
          return _select(
            returningQuery,
            withInsertId(substitutionValues, ids.first.first),
          );
        }),
      ),
    );
  }

  /// The rows of [sql], with its `@name` placeholders bound to
  /// [substitutionValues].
  List<List> _select(String sql, Map<String, dynamic> substitutionValues) {
    var (positional, params) = toPositional(sql, substitutionValues);
    logger.finest(() => 'SQL: $positional, parameters: $params');
    return _database.select(positional, params).rows;
  }

  /// Runs [f] in a transaction, which holds the database: a query given
  /// outside it, or another transaction, waits for it to end.
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
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) =>
      super.transaction(f);

  @override
  Future<T> _transaction<T>(
    _Scope scope,
    FutureOr<T> Function(QueryExecutor) f,
  ) async {
    // Named by its depth, as one savepoint of each depth runs at a time.
    var savepoint = scope.parent == null
        ? null
        : 'angel3_savepoint_${scope.depth}';
    _run(
      scope,
      () => _database.execute(
        savepoint == null ? 'BEGIN IMMEDIATE' : 'SAVEPOINT $savepoint',
      ),
    );
    try {
      var result = await _runCallback(
        scope,
        f,
        SqliteExecutor._of(this, scope),
      );
      _run(
        scope,
        () => _database.execute(
          savepoint == null ? 'COMMIT' : 'RELEASE $savepoint',
        ),
      );
      return result;
    } catch (_) {
      // Not if SQLite has rolled it back already, as of some errors, and its
      // savepoints with it.
      if (_database.autocommit) {
        // SQLite has ended the transaction, as of a statement given to the
        // database itself, so that the statements of its parent would run
        // outside it.
        scope.root.rolledBack = true;
      } else if (savepoint == null || !scope.root.rolledBack) {
        // A transaction is rolled back even if it is marked as rolled back,
        // as of a savepoint whose rollback failed, as the connection is still
        // in it.
        _rollBack(scope, savepoint);
      }
      rethrow;
    }
  }

  /// Rolls back [scope]: its savepoint, or its transaction. If that fails,
  /// the whole transaction is rolled back, as the connection would otherwise
  /// stay in it, or keep the writes of the savepoint, and it is marked as
  /// rolled back, so that it fails.
  void _rollBack(_Scope scope, String? savepoint) {
    try {
      _database.execute(
        savepoint == null
            ? 'ROLLBACK'
            : 'ROLLBACK TO $savepoint; RELEASE $savepoint',
      );
      return;
    } catch (e, st) {
      // The error of the transaction is thrown, not this one.
      logger.warning('The transaction could not be rolled back', e, st);
    }
    scope.root.rolledBack = true;
    if (_database.autocommit) return;
    try {
      _database.execute('ROLLBACK');
    } catch (e, st) {
      logger.severe('The connection is left in a transaction', e, st);
    }
  }
}
