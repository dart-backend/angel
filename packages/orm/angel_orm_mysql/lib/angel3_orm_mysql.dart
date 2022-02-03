import 'dart:async';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';

class MySqlExecutor extends QueryExecutor {
  /// An optional [Logger] to write to.
  final Logger? logger;

  final MySqlConnection _connection;

  MySqlExecutor(this._connection, {this.logger});

  final Dialect _dialect = const MySQLDialect();

  @override
  Dialect get dialect => _dialect;

  Future<void> close() {
    return _connection.close();
    /*
    if (_connection is MySqlConnection) {
      return (_connection as MySqlConnection).close();
    } else {
      return Future.value();
    }
    */
  }

  /*
  Future<Transaction> _startTransaction() {
    if (_connection is Transaction) {
      return Future.value(_connection as Transaction?);
    } else if (_connection is MySqlConnection) {
      return (_connection as MySqlConnection).begin();
    } else {
      throw StateError('Connection must be transaction or connection');
    }
  }
 
  @override
  Future<List<List>> query(
      String tableName, String query, Map<String, dynamic> substitutionValues,
      [List<String> returningFields = const []]) {
    // Change @id -> ?
    for (var name in substitutionValues.keys) {
      query = query.replaceAll('@$name', '?');
    }

    logger?.fine('Query: $query');
    logger?.fine('Values: $substitutionValues');

    if (returningFields.isNotEmpty != true) {
      return _connection!
          .prepared(query, substitutionValues.values)
          .then((results) => results.map((r) => r.toList()).toList());
    } else {
      return Future(() async {
        var tx = await _startTransaction();

        try {
          var writeResults =
              await tx.prepared(query, substitutionValues.values);
          var fieldSet = returningFields.map((s) => '`$s`').join(',');
          var fetchSql = 'select $fieldSet from $tableName where id = ?;';
          logger?.fine(fetchSql);
          var readResults =
              await tx.prepared(fetchSql, [writeResults.insertId]);
          var mapped = readResults.map((r) => r.toList()).toList();
          await tx.commit();
          return mapped;
        } catch (_) {
          await tx.rollback();
          rethrow;
        }
      });
    }
  }
 */

  @override
  Future<List<List>> query(
      String tableName, String query, Map<String, dynamic> substitutionValues,
      {String returningQuery = '',
      List<String> returningFields = const []}) async {
    // Change @id -> ?
    for (var name in substitutionValues.keys) {
      query = query.replaceAll('@$name', '?');
    }

    var params = substitutionValues.values.toList();

    logger?.fine('Query: $query');
    logger?.fine('Values: $params');
    logger?.fine('Returning Query: $returningQuery');

    if (returningQuery.isNotEmpty) {
      // Handle insert, update and delete
      // Retrieve back the inserted record
      var result = await _connection.query(query, params);
      query = '$returningQuery where id = ?';
      params = [result.insertId];
    }

    // Handle select
    return _connection.query(query, params).then((results) {
      return results.map((r) => r.toList()).toList();
    });
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    return f(this);
    /*
    if (_connection is! MySqlConnection) {
      return await f(this);
    }

    await _connection.transaction((context) async {
      var executor = MySqlExecutor(context, logger: logger);
    });
    */
  }
  /*
  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    if (_connection is Transaction) {
      return await f(this);
    }

    Transaction? tx;
    try {
      tx = await _startTransaction();
      var executor = MySqlExecutor(tx, logger: logger);
      var result = await f(executor);
      await tx.commit();
      return result;
    } catch (_) {
      await tx?.rollback();
      rethrow;
    }
  }
  */
}
