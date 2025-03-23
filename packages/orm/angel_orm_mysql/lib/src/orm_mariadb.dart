import 'dart:async';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';

class MariaDbExecutor extends QueryExecutor {
  /// An optional [Logger] print information to. A default logger will be used if not set
  late Logger logger;

  final MySqlConnection _connection;

  //TransactionContext? _transactionContext;

  MariaDbExecutor(this._connection, {Logger? logger}) {
    this.logger = logger ?? Logger('MariaDbExecutor');
  }

  final Dialect _dialect = const MySQLDialect();

  @override
  Dialect get dialect => _dialect;

  Future<void> close() {
    return _connection.close();
  }

  @override
  Future<List<List>> query(
      String tableName, String query, Map<String, dynamic> substitutionValues,
      {String returningQuery = '',
      String resultQuery = '',
      List<String> returningFields = const []}) async {
    // Change @id -> ?
    for (var name in substitutionValues.keys) {
      query = query.replaceAll('@$name', '?');
    }

    var params = substitutionValues.values.toList();
    for (var i = 0; i < params.length; i++) {
      var v = params[i];

      if (v is DateTime) {
        if (!v.isUtc) {
          params[i] = v.toUtc();
        }
      }
    }

    //logger.warning('Query: $query');
    //logger.warning('Values: $params');
    //logger.warning('Returning Query: $returningQuery');

    if (returningQuery.isNotEmpty) {
      // Handle insert, update and delete
      // Retrieve back the inserted record
      if (query.startsWith("INSERT")) {
        var result = await _connection.query(query, params);

        query = returningQuery;
        // logger?.warning('Result.insertId: ${result.insertId}');
        // Has primary key
        if (returningQuery.endsWith('.id=?')) {
          params = [result.insertId];
        }
      } else if (query.startsWith("UPDATE")) {
        await _connection.query(query, params);
        query = returningQuery;
        params = [];
      }
    }

    // Handle select
    return _connection.query(query, params).then((results) {
      return results.map((r) => r.toList()).toList();
    });
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    T? returnValue = await _connection.transaction((ctx) async {
      try {
        // TODO: To be refactored
        //logger.fine('Entering transaction');
        //var tx = MariaDbExecutor(conn, logger: logger);
        //TransactionContext transactionContext = ctx;
        return await f(this);
      } catch (e) {
        logger.severe('Failed to run transaction', e);
        rethrow;
      }
    });

    return returnValue!;
  }
}
