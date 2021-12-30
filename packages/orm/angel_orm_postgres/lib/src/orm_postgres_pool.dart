import 'dart:async';
import 'dart:convert';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:postgres_pool/postgres_pool.dart';

import '../angel3_orm_postgres.dart';

/// A [QueryExecutor] that uses `package:postgres_pool` for connetions pooling.
class PostgreSqlPoolExecutor extends QueryExecutor {
  final PgPool _pool;

  /// An optional [Logger] to print information to.
  late Logger logger;

  PostgreSqlPoolExecutor(this._pool, {Logger? logger}) {
    this.logger = logger ?? Logger('PostgreSqlPoolExecutor');
  }

  /// The underlying connection pooling.
  PgPool get pool => _pool;

  /// Closes all the connections in the pool.
  Future<dynamic> close() {
    return _pool.close();
  }

  /// Run query.
  @override
  Future<PostgreSQLResult> query(
      String tableName, String query, Map<String, dynamic> substitutionValues,
      [List<String> returningFields = const []]) {
    if (returningFields.isNotEmpty) {
      var fields = returningFields.join(', ');
      var returning = 'RETURNING $fields';
      query = '$query $returning';
    }

    //logger.fine('Query: $query');
    //logger.fine('Values: $substitutionValues');

    // Convert List into String
    var param = <String, dynamic>{};
    substitutionValues.forEach((key, value) {
      if (value is List) {
        param[key] = jsonEncode(value);
      } else {
        param[key] = value;
      }
    });

    return _pool.run<PostgreSQLResult>((pgContext) async {
      return await pgContext.query(query, substitutionValues: param);
    });
  }

  /// Run query in a transaction.
  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    return _pool.runTx((pgContext) async {
      var exec = PostgreSqlExecutor(pgContext, logger: logger);
      return await f(exec);
    });
  }
}
