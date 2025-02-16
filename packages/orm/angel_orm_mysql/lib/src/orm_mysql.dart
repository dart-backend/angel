import 'dart:async';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';

class MySqlExecutor extends QueryExecutor {
  /// An optional [Logger] to write to. A default logger will be used if not set
  late Logger _logger;

  final MySQLConnection _connection;

  MySqlExecutor(this._connection, {Logger? logger}) {
    _logger = logger ?? Logger('MySqlExecutor');
  }

  final Dialect _dialect = const MySQLDialect();

  @override
  Dialect get dialect => _dialect;

  Future<void> close() {
    return _connection.close();
  }

  MySQLConnection get rawConnection => _connection;

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
      query = query.replaceAll('@$name', ':$name');

      // Convert UTC time to local time
      var value = substitutionValues[name];
      if (value is DateTime && value.isUtc) {
        var t = value.toLocal();
        //_logger.fine('Datetime deteted: $name');
        //_logger.fine('Datetime: UTC -> $value, Local -> $t');

        substitutionValues[name] = t;
      }
    }

    //_logger.fine('Query: $query');
    //_logger.fine('Values: $substitutionValues');
    //_logger.fine('Returning Query: $returningQuery');

    if (returningQuery.isNotEmpty) {
      // Handle insert, update and delete
      // Retrieve back the inserted record
      if (query.startsWith("INSERT")) {
        var result = await _connection.execute(query, substitutionValues);

        //logger.fine(result.lastInsertID);

        query = returningQuery;
        //logger.fine('Result.insertId: ${result.insertId}');
        // Has primary key
        if (returningQuery.endsWith('.id=?')) {
          query = query.replaceAll("?", ":id");
          substitutionValues.clear();
          substitutionValues['id'] = result.lastInsertID;
        } else {
          query = _convertSQL(query, substitutionValues);
        }
      } else if (query.startsWith("UPDATE")) {
        await _connection.execute(query, substitutionValues);
        query = returningQuery;
      }
    }

    // Select the deleted records prior to being delete
    var isDeleteQuery = query.startsWith("DELETE");
    List<List<dynamic>> deletedResults = [];
    if (isDeleteQuery) {
      var selectQuery = query.replaceFirst("DELETE", "SELECT *");
      //_logger.fine('Select query for delete: $selectQuery');

      deletedResults = await _connection
          .execute(selectQuery, substitutionValues)
          .then((results) {
        return results.rows.map((r) => r.typedAssoc().values.toList()).toList();
      });
    }

    //_logger.fine('Query 2: $query');
    //_logger.fine('Values 2: $substitutionValues');

    // Handle select
    return _connection.execute(query, substitutionValues).then((results) {
      if (isDeleteQuery) {
        return deletedResults;
      } else {
        //return results.rows.map((r) => r.typedAssoc().values.toList()).toList();
        return parseSQLResult(results);
      }
    });
  }

  String _convertSQL(String query, Map<String, dynamic> substitutionValues) {
    var newQuery = query;
    for (var k in substitutionValues.keys) {
      var fromPattern = '.$k = ?';
      var toPattern = '.$k = :$k';
      newQuery = newQuery.replaceFirst(fromPattern, toPattern);
    }

    return newQuery;
  }

  List<List<dynamic>> parseSQLResult(IResultSet res) {
    var colTypes = res.cols.map((col) => col.type).toList();

    var mappedResult = <List>[];
    for (var row in res.rows) {
      List<dynamic> retResult = [];
      for (var i = 0; i < row.numOfColumns; i++) {
        var val = row.typedColAt(i);

        //retResult.add(colTypes[i].convertStringValueToProvidedType(val));
        retResult.add(val);
      }
      mappedResult.add(retResult);
    }

    return mappedResult;
  }

  /*
  Map<String, dynamic> parseSQLNamedResult(IResultSet res) {
    var colNames = [];
    var columns = [];
    var prefix = "1__";
    for (var c in res.cols) {
      if (colNames.contains(c.name)) {
        // If collumn name is duplicated, add "1_" as prefix
        var tmpColName = "$prefix${c.name}";
        while (colNames.contains(tmpColName)) {
          tmpColName = "$prefix$tmpColName";
        }
        columns.add((name: tmpColName, type: c.type));
        colNames.add(tmpColName);
      } else {
        columns.add((name: c.name, type: c.type));
        colNames.add(c.name);
      }
    }

    var row = res.rows.first;

    Map<String, dynamic> retResult = {};
    for (var i = 0; i < row.numOfColumns; i++) {
      var val = row.typedColAt(i);
      var colName = columns[i].name;

      retResult[colName] = val;
    }

    return retResult;
  }
  */

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    //logger.warning("Transaction");

    T? returnValue = await _connection.transactional((ctx) async {
      try {
        //logger.fine('Entering transaction');
        var tx = MySqlExecutor(ctx, logger: _logger);
        return await f(tx);
      } catch (e) {
        _logger.severe('Failed to run transaction', e);
        rethrow;
      }
    });

    return returnValue!;
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
