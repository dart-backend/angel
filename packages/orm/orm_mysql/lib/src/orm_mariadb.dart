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
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) async {
    var params = <dynamic>[];
    query = _toPositional(query, substitutionValues, params);

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
        if (returningQuery.endsWith('.id=?')) {
          // Has primary key
          params = [result.insertId];
        } else if (!returningQuery.contains('?')) {
          // The last row by id: mysql1 rejects parameters it has no
          // placeholders for.
          params = [];
        }
        // Otherwise the row is selected by the inserted values, which
        // keep the order of the INSERT's placeholders.
      } else if (query.startsWith("UPDATE")) {
        await _connection.query(query, params);
        params = [];
        query = _toPositional(returningQuery, substitutionValues, params);
      }
    }

    // Handle select
    return _connection.query(query, params).then((results) {
      return results.map((r) => r.toList()).toList();
    });
  }

  /// A placeholder: `@` and a name of letters (in any script), digits and
  /// underscores.
  static final _placeholder = RegExp(r'@([\p{L}\p{N}_]+)', unicode: true);

  /// Changes the `@name` placeholders in [sql] to `?`, and adds their
  /// values to [params] in the order the placeholders appear. Matching
  /// whole names keeps `@name` from replacing part of `@name1`.
  String _toPositional(
    String sql,
    Map<String, dynamic> substitutionValues,
    List<dynamic> params,
  ) {
    return sql.replaceAllMapped(_placeholder, (m) {
      var name = m[1]!;
      if (!substitutionValues.containsKey(name)) return m[0]!;
      var value = substitutionValues[name];
      params.add(value is DateTime && !value.isUtc ? value.toUtc() : value);
      return '?';
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
