import 'dart:async';
import 'dart:io';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';
import 'package:mysql_client/mysql_client.dart';

List tmpTables = [];

FutureOr<QueryExecutor> Function() createTables(List<String> schemas) {
  // For MySQL
  return () => _connectToMySql(schemas);

  // For MariaDB
  //return () => _connectToMariaDb(schemas);
}

// For MySQL
Future<void> dropTables(QueryExecutor executor) async {
  var sqlExecutor = (executor as MySqlExecutor);
  for (var tableName in tmpTables.reversed) {
    print('DROP TABLE $tableName');
    await sqlExecutor.rawConnection.execute('DROP TABLE $tableName;');
  }

  return sqlExecutor.close();
}

// For MariaDB
Future<void> dropTables2(QueryExecutor executor) {
  var sqlExecutor = (executor as MariaDbExecutor);
  for (var tableName in tmpTables.reversed) {
    print('DROP TABLE $tableName');
    sqlExecutor.query(tableName, 'DROP TABLE $tableName', {});
  }
  return sqlExecutor.close();
}

String extractTableName(String createQuery) {
  var start = createQuery.indexOf('EXISTS');
  var end = createQuery.indexOf('(');

  if (start == -1 || end == -1) {
    return '';
  }

  return createQuery.substring(start + 6, end).trim();
}

// Executor for MariaDB
Future<MariaDbExecutor> _connectToMariaDb(List<String> schemas) async {
  var settings = ConnectionSettings(
      host: 'localhost',
      port: 3306,
      db: 'orm_test',
      user: 'test',
      password: 'test123');
  var connection = await MySqlConnection.connect(settings);

  var logger = Logger('orm_mariadb');

  tmpTables.clear();

  for (var s in schemas) {
    // MySQL driver does not support multiple sql queries
    var data = await File('test/migrations/$s.sql').readAsString();
    var queries = data.split(";");
    for (var q in queries) {
      print("Table: [$q]");
      if (q.trim().isNotEmpty) {
        //await connection.execute(q);
        await connection.query(q);

        var tableName = extractTableName(q);
        if (tableName != '') {
          tmpTables.add(tableName);
        }
      }
    }
  }

  return MariaDbExecutor(connection, logger: logger);
}

// Executor for MySQL
Future<MySqlExecutor> _connectToMySql(List<String> schemas) async {
  var connection = await MySQLConnection.createConnection(
      databaseName: 'orm_test',
      port: 3306,
      host: "localhost",
      userName: Platform.environment['MYSQL_USERNAME'] ?? 'test',
      password: Platform.environment['MYSQL_PASSWORD'] ?? 'test123',
      secure: false);

  await connection.connect(timeoutMs: 10000);

  var logger = Logger('orm_mysql');

  tmpTables.clear();

  for (var s in schemas) {
    // MySQL driver does not support multiple sql queries
    var data = await File('test/migrations/$s.sql').readAsString();
    var queries = data.split(";");
    for (var q in queries) {
      //print("Table: [$q]");
      if (q.trim().isNotEmpty) {
        await connection.execute(q);

        var tableName = extractTableName(q);
        if (tableName != '') {
          tmpTables.add(tableName);
        }
      }
    }
  }

  return MySqlExecutor(connection, logger: logger);
}
