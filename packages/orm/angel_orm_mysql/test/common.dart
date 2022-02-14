import 'dart:async';
import 'dart:io';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';

FutureOr<QueryExecutor> Function() my(Iterable<String> schemas) {
  return () => connectToMySql(schemas);
}

Future<void> closeMy(QueryExecutor executor) =>
    (executor as MySqlExecutor).close();

Future<MySqlExecutor> connectToMySql(Iterable<String> schemas) async {
  var settings = ConnectionSettings(
      db: 'orm_test',
      host: "localhost",
      user: Platform.environment['MYSQL_USERNAME'] ?? 'Test',
      password: Platform.environment['MYSQL_PASSWORD'] ?? 'Test123*',
      timeout: Duration(minutes: 10));
  var connection = await MySqlConnection.connect(settings);
  var logger = Logger('orm_mysql');

  for (var s in schemas) {
    // MySQL driver does not support multiple sql queries
    var data = await File('test/migrations/$s.sql').readAsString();
    var queries = data.split(";");
    for (var q in queries) {
      //print("Table: [$q]");
      if (q.trim().isNotEmpty) {
        await connection.query(q);
      }
    }
  }

  return MySqlExecutor(connection, logger: logger);
}
