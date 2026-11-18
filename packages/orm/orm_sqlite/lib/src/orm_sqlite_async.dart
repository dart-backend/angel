part of 'executors.dart';

/// A [QueryExecutor] of a SQLite database of the `sqlite_async` package, on
/// SQLite 3.35 or later, which runs its statements on connections of their
/// own, in background isolates, so that they do not block the isolate that
/// gives them, as on a server.
///
/// `sqlite_async` writes on one connection, and reads on others, in WAL mode,
/// at the same time as it writes. A query outside a transaction that only
/// reads, a `SELECT`, runs on a connection that reads: it does not wait for a
/// transaction, and sees the rows as they were before it. Another, and
/// another transaction, waits for the transaction, as `sqlite_async` writes
/// one at a time.
///
/// On one connection, as of [SqliteDatabase.singleConnection], such as one in
/// memory, there is no connection that reads: a query that reads waits for a
/// transaction too, as one that writes does.
///
/// A query given in a transaction, to the executor of its callback, or to any
/// executor of the database by the code of its callback, runs in it. The
/// statements of a transaction run one at a time. Values are stored as
/// [SqliteExecutor] stores them.
class SqliteAsyncExecutor extends _SqliteExecutorBase<SqliteConnection> {
  /// An executor of [database], such as a [SqliteDatabase], which pools its
  /// connections.
  SqliteAsyncExecutor(SqliteConnection database, {Logger? logger})
    : super(
        database,
        logger ?? Logger('SqliteAsyncExecutor'),
        outsideWaits: false,
      );

  SqliteAsyncExecutor._of(super.executor, super.bound) : super._of();

  /// The database of `sqlite_async`.
  SqliteConnection get database => _database;

  @override
  Future<void> _closeDatabase() => _database.close();

  @override
  Future<List<List>> query(
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) {
    var scope = _scope;
    return _whenReady(scope, () {
      var context = scope?.context as SqliteWriteContext?;
      // The statements are given to `sqlite_async` in this microtask, so
      // that a savepoint cannot begin on [context] before them, and as the
      // one statement of the transaction that runs: no other of it runs
      // until the executor knows whether SQLite rolled it back.
      return _scopes.hold(scope, () async {
        try {
          if (!selectsInsertedRow(query, returningQuery)) {
            return (await _statement(context, query, substitutionValues)).rows;
          }
          // The insert and the select of its row, on one connection,
          // outside a transaction as in one.
          return context != null
              ? await _insert(
                  context,
                  query,
                  returningQuery,
                  substitutionValues,
                )
              : await _database.writeLock(
                  (tx) =>
                      _insert(tx, query, returningQuery, substitutionValues),
                );
        } catch (_) {
          if (scope != null && context != null) {
            await _checkRolledBack(scope, context);
          }
          rethrow;
        }
      });
    });
  }

  /// Marks the transaction of [scope] as rolled back if SQLite rolled it
  /// back, after an error of a statement of [context].
  Future<void> _checkRolledBack(
    _Scope scope,
    SqliteWriteContext context,
  ) async {
    try {
      if (await context.getAutoCommit()) scope.root.rolledBack = true;
    } catch (_) {
      // The context has ended, and the transaction with it.
      scope.root.rolledBack = true;
    }
  }

  /// The result of [sql]: on [context], or, outside a transaction, on a
  /// connection that reads, if it only reads, or else on the one that writes.
  ///
  /// It is given to `sqlite_async` in the microtask of its call.
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

  Future<List<List>> _insert(
    SqliteWriteContext context,
    String query,
    String returningQuery,
    Map<String, dynamic> substitutionValues,
  ) async {
    var ids = await _statement(context, returningId(query), substitutionValues);
    if (ids.isEmpty) return [];
    var row = await _statement(
      context,
      returningQuery,
      withInsertId(substitutionValues, ids.rows.first.first),
    );
    return row.rows;
  }

  /// Runs [f] in a transaction of `sqlite_async`'s `writeTransaction`, which
  /// begins with `BEGIN IMMEDIATE`. A query outside it that writes, and
  /// another transaction, waits for it to end; one that reads does not,
  /// unless the database has one connection.
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
  /// elsewhere, waits for it to end, so [f] must not wait for it; nor for
  /// one that reads, on a database of one connection.
  ///
  /// If a savepoint fails and its rollback fails too, which is rare,
  /// `sqlite_async` ignores the error of the rollback, so that its writes may
  /// be committed with the transaction, unlike with [SqliteExecutor].
  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) =>
      super.transaction(f);

  @override
  Future<T> _transaction<T>(
    _Scope scope,
    FutureOr<T> Function(QueryExecutor) f,
  ) {
    Future<T> body(SqliteWriteContext tx) {
      scope.context = tx;
      return _runCallback(scope, f, SqliteAsyncExecutor._of(this, scope));
    }

    var parentContext = scope.parent?.context as SqliteWriteContext?;
    // Called in this microtask, so that `sqlite_async` locks the context of
    // the parent before a statement of it is given.
    return parentContext == null
        ? _database.writeTransaction(body)
        : parentContext.writeTransaction(body);
  }
}
