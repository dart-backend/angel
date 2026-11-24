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
          try {
            if (!selectsInsertedRow(query, returningQuery)) {
              return _select(query, substitutionValues);
            }
            return _atomically(scope, () {
              var ids = _select(returningId(query), substitutionValues);
              if (ids.isEmpty) return <List>[];
              return _select(
                returningQuery,
                withInsertId(substitutionValues, ids.first.first),
              );
            });
          } on SqliteException catch (e) {
            _recordSource(e, tableName);
            rethrow;
          }
        }),
      ),
    );
  }

  /// The result of [f], whose statements are rolled back if it fails: as an
  /// insert and the select of its row, so that the row is not inserted if
  /// the select fails. In a savepoint, which nests in a transaction of
  /// [scope], or in one that the connection is in, as of a `BEGIN` given to
  /// the database itself, and is a transaction of its own outside them.
  ///
  /// If the rollback fails, the transaction of [scope] is marked as rolled
  /// back, so that it fails rather than commits the row; outside one, the
  /// transaction that the savepoint began is rolled back whole.
  R _atomically<R>(_Scope? scope, R Function() f) {
    // Whether the savepoint begins a transaction, which is its own.
    var begins = _database.autocommit;
    _database.execute('SAVEPOINT angel3_insert');
    try {
      var result = f();
      _database.execute('RELEASE angel3_insert');
      return result;
    } catch (_) {
      // Not if SQLite has rolled back the transaction, and the savepoint.
      if (!_database.autocommit) {
        try {
          _database.execute('ROLLBACK TO angel3_insert; RELEASE angel3_insert');
        } catch (e, st) {
          if (scope != null) {
            // Rolled back whole by [_transaction], as it fails.
            logger.warning('The insert could not be rolled back', e, st);
            scope.root.rolledBack = true;
          } else {
            _afterFailedRollback('The insert', e, st, rollBackAll: begins);
          }
        }
      }
      rethrow;
    }
  }

  /// Records [table], of the statement that failed with [error], for
  /// [classifySqliteError], with the names of its `CHECK`s if it failed one.
  void _recordSource(SqliteException error, String table) {
    Set<String>? checks;
    if (isCheckError(error)) {
      try {
        var schemas = [
          for (var row in _database.select(schemasQuery)) row['name'] as String,
        ];
        for (var (schema, name) in tableCandidates(schemas, table)) {
          var rows = _database.select(tableSqlQuery(schema), [name]);
          if (rows.isEmpty) continue;
          checks = checkNames(rows.first['sql'] as String?);
          break;
        }
      } catch (_) {
        // Its constraint is not named.
      }
    }
    recordSqliteErrorSource(error, table, checks: checks);
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
  /// it is marked as rolled back, so that it fails, and the whole
  /// transaction is rolled back, as the connection would otherwise stay in
  /// it, or keep the writes of the savepoint.
  void _rollBack(_Scope scope, String? savepoint) {
    try {
      _database.execute(
        savepoint == null
            ? 'ROLLBACK'
            : 'ROLLBACK TO $savepoint; RELEASE $savepoint',
      );
    } catch (e, st) {
      // The error of the transaction is thrown, not this one.
      scope.root.rolledBack = true;
      _afterFailedRollback(
        savepoint == null ? 'The transaction' : 'The savepoint',
        e,
        st,
        // A whole transaction that failed to roll back would fail again.
        rollBackAll: savepoint != null,
      );
    }
  }

  /// Logs that the rollback of [what] failed with [error]: as a warning if
  /// the connection is no longer in a transaction, once [rollBackAll] has
  /// rolled back the one it is in; or else as severe, as it is left in it.
  void _afterFailedRollback(
    String what,
    Object error,
    StackTrace stackTrace, {
    required bool rollBackAll,
  }) {
    if (rollBackAll && !_database.autocommit) {
      try {
        _database.execute('ROLLBACK');
      } catch (e, st) {
        (error, stackTrace) = (e, st);
      }
    }
    if (_database.autocommit) {
      logger.warning(
        '$what could not be rolled back; the connection is no longer in a '
        'transaction',
        error,
        stackTrace,
      );
    } else {
      logger.severe(
        '$what could not be rolled back, and the connection is left in a '
        'transaction',
        error,
        stackTrace,
      );
    }
  }
}
