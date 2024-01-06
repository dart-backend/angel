import 'dart:async';
import 'dart:io';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

FutureOr<QueryExecutor> Function() pg(Iterable<String> schemas) {
  // Use single connection
  return () => connectToPostgres(schemas);

  // Use connection pooling with 1 connection
  //return () => connectToPostgresPool(schemas);

  // Use PostgreSqlExecutorPool (Not working)
  //return () => connectToPostgresPool1(schemas);
}

Future<void> closePg(QueryExecutor executor) async {
  if (executor is PostgreSqlExecutor) {
    await executor.close();
  }
}

Future<PostgreSqlExecutor> connectToPostgres(Iterable<String> schemas) async {
  var conn = await Connection.open(Endpoint(
      host: 'localhost',
      port: 5432,
      database: Platform.environment['POSTGRES_DB'] ?? 'orm_test',
      username: Platform.environment['POSTGRES_USERNAME'] ?? 'test',
      password: Platform.environment['POSTGRES_PASSWORD'] ?? 'test123'));

  // Run sql to create the tables
  for (var s in schemas) {
    await conn.execute(await File('test/migrations/$s.sql').readAsString());
  }

  return PostgreSqlExecutor(conn, logger: Logger.root);
}

Future<PostgreSqlExecutorPool> connectToPostgresPool1(
    Iterable<String> schemas) async {
  PostgreSQLConnection connectionFactory() {
    return PostgreSQLConnection(
        'localhost', 5432, Platform.environment['POSTGRES_DB'] ?? 'orm_test',
        username: Platform.environment['POSTGRES_USERNAME'] ?? 'test',
        password: Platform.environment['POSTGRES_PASSWORD'] ?? 'test123');
  }

  PostgreSQLConnection conn = connectionFactory();
  await conn.open();

  // Run sql to create the tables
  for (var s in schemas) {
    await conn.execute(await File('test/migrations/$s.sql').readAsString());
  }

  return PostgreSqlExecutorPool(5, connectionFactory, logger: Logger.root);
}

Future<PostgreSqlPoolExecutor> connectToPostgresPool(
    Iterable<String> schemas) async {
  var dbPool = PgPool(
    PgEndpoint(
      host: 'localhost',
      port: 5432,
      database: Platform.environment['POSTGRES_DB'] ?? 'orm_test',
      username: Platform.environment['POSTGRES_USERNAME'] ?? 'test',
      password: Platform.environment['POSTGRES_PASSWORD'] ?? 'test123',
    ),
    settings: PgPoolSettings()
      ..maxConnectionAge = Duration(hours: 1)
      ..concurrency = 200,
  );

  // Run sql to create the tables in a transaction
  //await _pool.runTx((conn) async {
  //  for (var s in schemas) {
  //    await conn.execute(await File('test/migrations/$s.sql').readAsString());
  //  }
  //});

  return PostgreSqlPoolExecutor(dbPool, logger: Logger.root);
}
