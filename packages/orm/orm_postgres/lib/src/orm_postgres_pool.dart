import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import '../angel3_orm_postgres.dart';

/// A [QueryExecutor] that uses `package:postgres_pool` for connetions pooling.
class PostgreSqlPoolExecutor extends QueryExecutor {
  final Pool _pool;

  /// An optional [Logger] to print information to.
  late Logger logger;

  PostgreSqlPoolExecutor(this._pool, {Logger? logger}) {
    this.logger = logger ?? Logger('PostgreSqlPoolExecutor');
  }

  final Dialect _dialect = const PostgreSQLDialect();

  @override
  Dialect get dialect => _dialect;

  /// The underlying connection pooling.
  Pool get pool => _pool;

  /// Closes all the connections in the pool.
  Future<dynamic> close() {
    return _pool.close();
  }

  /// Runs [query] on a connection of the pool, as [PostgreSqlExecutor.query]
  /// does, which logs it the same way and runs it as given.
  @override
  Future<Result> query(
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) => PostgreSqlExecutor(_pool, logger: logger).query(
    tableName,
    query,
    substitutionValues,
    returningQuery: returningQuery,
    resultQuery: resultQuery,
    returningFields: returningFields,
  );

  /// Runs [f] in a transaction, on a connection of the pool, as
  /// [PostgreSqlExecutor.transaction] does. To nest a transaction, call
  /// `transaction` on the executor [f] is given, which runs in a savepoint.
  ///
  /// Calling it on this executor from inside [f] runs an independent
  /// transaction on another connection, committed or rolled back on its own,
  /// once the pool has a connection free: with none, as with a pool of one
  /// connection, it waits forever, as [f] waits for it.
  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) =>
      PostgreSqlExecutor(_pool, logger: logger).transaction(f);
}
