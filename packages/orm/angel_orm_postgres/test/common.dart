import 'dart:async';
import 'dart:io';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

FutureOr<QueryExecutor> Function() pg(Iterable<String> schemas) {
  return () => connectToPostgres(schemas);
}

Future<void> closePg(QueryExecutor executor) =>
    (executor as PostgreSqlExecutor).close();

Future<PostgreSqlExecutor> connectToPostgres(Iterable<String> schemas) async {
  var conn = PostgreSQLConnection('127.0.0.1', 5432, 'orm_test',
      username: Platform.environment['POSTGRES_USERNAME'] ?? 'test',
      password: Platform.environment['POSTGRES_PASSWORD'] ?? 'test123');
  await conn.open();

  // Run sql to create the tables
  for (var s in schemas) {
    await conn.execute(await File('test/migrations/$s.sql').readAsString());
  }

  return PostgreSqlExecutor(conn, logger: Logger.root);
}
