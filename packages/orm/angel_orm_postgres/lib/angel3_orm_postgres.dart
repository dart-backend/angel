import 'dart:async';
import 'dart:convert';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:pool/pool.dart';
import 'package:postgres/postgres.dart';

/// A [QueryExecutor] that queries a PostgreSQL database.
class PostgreSqlExecutor extends QueryExecutor {
  final PostgreSQLExecutionContext _connection;

  /// An optional [Logger] to print information to.
  late Logger logger;

  PostgreSqlExecutor(this._connection, {Logger? logger}) {
    if (logger != null) {
      this.logger = logger;
    } else {
      this.logger = Logger('PostgreSqlExecutor');
    }
  }

  /// The underlying connection.
  PostgreSQLExecutionContext get connection => _connection;

  /// Closes the connection.
  Future close() {
    if (_connection is PostgreSQLConnection) {
      return (_connection as PostgreSQLConnection).close();
    } else {
      return Future.value();
    }
  }

  @override
  Future<List<List>> query(
      String tableName, String query, Map<String, dynamic> substitutionValues,
      [List<String>? returningFields]) {
    if (returningFields != null) {
      var fields = returningFields.join(', ');
      var returning = 'RETURNING $fields';
      query = '$query $returning';
    }

    logger.fine('Query: $query');
    logger.fine('Values: $substitutionValues');

    // Convert List into String
    var param = <String, dynamic>{};
    substitutionValues.forEach((key, value) {
      if (value is List) {
        param[key] = jsonEncode(value);
      } else {
        param[key] = value;
      }
    });

    return _connection.query(query, substitutionValues: param);
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) async {
    if (_connection is! PostgreSQLConnection) {
      return await f(this);
    }

    var conn = _connection as PostgreSQLConnection;
    T? returnValue;

    var txResult = await conn.transaction((ctx) async {
      try {
        logger.fine('Entering transaction');
        var tx = PostgreSqlExecutor(ctx, logger: logger);
        returnValue = await f(tx);

        return returnValue;
      } catch (e) {
        ctx.cancelTransaction(reason: e.toString());
        rethrow;
      } finally {
        logger.fine('Exiting transaction');
      }
    });

    if (txResult is PostgreSQLRollback) {
      //if (txResult.reason == null) {
      //  throw StateError('The transaction was cancelled.');
      //} else {
      throw StateError(
          'The transaction was cancelled with reason "${txResult.reason}".');
      //}
    } else {
      return returnValue!;
    }
  }
}

/// A [QueryExecutor] that manages a pool of PostgreSQL connections.
class PostgreSqlExecutorPool extends QueryExecutor {
  /// The maximum amount of concurrent connections.
  final int size;

  /// Creates a new [PostgreSQLConnection], on demand.
  ///
  /// The created connection should **not** be open.
  final PostgreSQLConnection Function() connectionFactory;

  /// An optional [Logger] to print information to.
  late Logger logger;

  final List<PostgreSqlExecutor> _connections = [];
  int _index = 0;
  final Pool _pool, _connMutex = Pool(1);

  PostgreSqlExecutorPool(this.size, this.connectionFactory, {Logger? logger})
      : _pool = Pool(size) {
    if (logger != null) {
      this.logger = logger;
    } else {
      this.logger = Logger('PostgreSqlExecutorPool');
    }

    assert(size > 0, 'Connection pool cannot be empty.');
  }

  /// Closes all connections.
  Future close() async {
    await _pool.close();
    await _connMutex.close();
    return Future.wait(_connections.map((c) => c.close()));
  }

  Future _open() async {
    if (_connections.isEmpty) {
      _connections.addAll(await Future.wait(List.generate(size, (_) {
        logger.fine('Spawning connections...');
        var conn = connectionFactory();
        return conn
            .open()
            .then((_) => PostgreSqlExecutor(conn, logger: logger));
      })));
    }
  }

  Future<PostgreSqlExecutor> _next() {
    return _connMutex.withResource(() async {
      await _open();
      if (_index >= size) _index = 0;
      return _connections[_index++];
    });
  }

  @override
  Future<List<List>> query(
      String tableName, String query, Map<String, dynamic> substitutionValues,
      [List<String>? returningFields]) {
    return _pool.withResource(() async {
      var executor = await _next();
      return executor.query(
          tableName, query, substitutionValues, returningFields);
    });
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) {
    return _pool.withResource(() async {
      var executor = await _next();
      return executor.transaction(f);
    });
  }
}
