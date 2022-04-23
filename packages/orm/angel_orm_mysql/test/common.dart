import 'dart:async';
import 'dart:io';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';
import 'package:mysql_client/mysql_client.dart';

FutureOr<QueryExecutor> Function() my(Iterable<String> schemas) {
  return () => connectToMySql(schemas);
}

Future<void> closeMy(QueryExecutor executor) =>
    (executor as MySqlExecutor).close();

// Executor for MariaDB 10.2.x
Future<MariaDbExecutor> connectToMariaDb(Iterable<String> schemas) async {
  var settings = ConnectionSettings(
      host: 'localhost',
      port: 3306,
      db: 'orm_test',
      user: 'Test',
      password: 'Test123*');
  var connection = await MySqlConnection.connect(settings);

  var logger = Logger('orm_mysql');

  for (var s in schemas) {
    // MySQL driver does not support multiple sql queries
    var data = await File('test/migrations/$s.sql').readAsString();
    var queries = data.split(";");
    for (var q in queries) {
      //print("Table: [$q]");
      if (q.trim().isNotEmpty) {
        //await connection.execute(q);
        await connection.query(q);
      }
    }
  }

  return MariaDbExecutor(connection, logger: logger);
}

// Executor for MySQL 8.x.x
Future<MySqlExecutor> connectToMySql(Iterable<String> schemas) async {
  var connection = await MySQLConnection.createConnection(
    databaseName: 'orm_test',
    port: 3306,
    host: "localhost",
    userName: Platform.environment['MYSQL_USERNAME'] ?? 'test',
    password: Platform.environment['MYSQL_PASSWORD'] ?? 'Test123*',
  );

  await connection.connect();

  var logger = Logger('orm_mysql');

  for (var s in schemas) {
    // MySQL driver does not support multiple sql queries
    var data = await File('test/migrations/$s.sql').readAsString();
    var queries = data.split(";");
    for (var q in queries) {
      //print("Table: [$q]");
      if (q.trim().isNotEmpty) {
        await connection.execute(q);
      }
    }
  }

  return MySqlExecutor(connection, logger: logger);
}
