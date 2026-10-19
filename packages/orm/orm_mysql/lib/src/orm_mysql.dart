import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:mysql_dart/mysql_dart.dart';

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

  /// The end of the commands queued on each connection, of [_serial].
  static final Expando<Future<void>> _queues = Expando('MySqlExecutor queue');

  /// The key of the zone of the commands that run in the queue of a
  /// connection, whose value is that connection.
  static final Object _queueKey = Object();

  /// Runs [command] when the commands queued before it on the connection have
  /// run, as `mysql_dart` runs one command at a time on a connection: it
  /// rejects, or fails to decode the response of, one sent while another
  /// runs. A command of one already in the queue, as a query of a
  /// transaction, runs as it is, as it would wait for itself.
  Future<T> _serial<T>(Future<T> Function() command) {
    if (identical(Zone.current[_queueKey], _connection)) return command();
    var previous = _queues[_connection] ?? Future<void>.value();
    var result = previous.then(
      (_) => runZoned(command, zoneValues: {_queueKey: _connection}),
    );
    _queues[_connection] = result.then((_) {}, onError: (_) {});
    return result;
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
    String tableName,
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) => _serial(
    () => _query(query, substitutionValues, returningQuery: returningQuery),
  );

  /// The rows of [query], whose commands, as an insert and the select of its
  /// row, run in one turn of the queue of the connection.
  Future<List<List>> _query(
    String query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
  }) async {
    var params = <String, dynamic>{};
    query = _toNamed(query, substitutionValues, params);

    //_logger.fine('Query: $query');
    //_logger.fine('Values: $params');
    //_logger.fine('Returning Query: $returningQuery');

    if (returningQuery.isNotEmpty) {
      // Handle insert, update and delete
      // Retrieve back the inserted record
      if (query.startsWith("INSERT")) {
        var result = await _connection.execute(query, params);

        //logger.fine(result.lastInsertID);

        query = returningQuery;
        //logger.fine('Result.insertId: ${result.insertId}');
        // Has primary key
        if (returningQuery.endsWith('.id=?')) {
          // Of the id the database gave the row.
          query = query.replaceAll("?", ":id");
          // As an int, as `mysql_dart` binds no BigInt.
          params = {'id': result.lastInsertID.toInt()};
        } else if (returningQuery.contains('@')) {
          // Of the id given, by its parameter, as of a key the database does
          // not generate, of which it gives no insert id.
          params = {};
          query = _toNamed(returningQuery, substitutionValues, params);
        } else {
          // The row is selected by the inserted values, whose `?` keep the
          // order of the INSERT's placeholders.
          var i = 0;
          query = query.replaceAllMapped('?', (_) => ':${_paramName(i++)}');
        }
      } else if (query.startsWith("UPDATE")) {
        await _connection.execute(query, params);
        params = {};
        query = _toNamed(returningQuery, substitutionValues, params);
      }
    }

    // Select the deleted records prior to being delete
    var isDeleteQuery = query.startsWith("DELETE");
    List<List<dynamic>> deletedResults = [];
    if (isDeleteQuery) {
      var selectQuery = query.replaceFirst("DELETE", "SELECT *");
      //_logger.fine('Select query for delete: $selectQuery');

      deletedResults = await _connection.execute(selectQuery, params).then((
        results,
      ) {
        return results.rows.map((r) => r.typedAssoc().values.toList()).toList();
      });
    }

    //_logger.fine('Query 2: $query');
    //_logger.fine('Values 2: $params');

    // Handle select
    return _connection.execute(query, params).then((results) {
      if (isDeleteQuery) {
        return deletedResults;
      } else {
        //return results.rows.map((r) => r.typedAssoc().values.toList()).toList();
        return parseSQLResult(results);
      }
    });
  }

  /// Changes the `@name` placeholders in [sql] to `:p0`, `:p1`, ... in the
  /// order they appear, and adds their values to [params] by those names.
  ///
  /// `mysql_dart` only finds `:name` placeholders of ASCII letters, digits
  /// and underscores, so the names of the columns are not used. A UTC
  /// [DateTime] is sent as local time.
  String _toNamed(
    String sql,
    Map<String, dynamic> substitutionValues,
    Map<String, dynamic> params,
  ) {
    return replacePlaceholders(sql, substitutionValues, (_, value) {
      var name = _paramName(params.length);
      params[name] = value is DateTime && value.isUtc ? value.toLocal() : value;
      return ':$name';
    });
  }

  static String _paramName(int i) => 'p$i';

  List<List<dynamic>> parseSQLResult(IResultSet res) {
    //var colTypes = res.cols.map((col) => col.type).toList();

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

    // In the queue of the connection, which its queries run in.
    T? returnValue = await _serial(
      () => _connection.transactional((ctx) async {
        try {
          //logger.fine('Entering transaction');
          var tx = MySqlExecutor(ctx, logger: _logger);
          return await f(tx);
        } catch (e) {
          _logger.severe('Failed to run transaction', e);
          rethrow;
        }
      }),
    );

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
