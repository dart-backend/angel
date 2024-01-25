import 'dart:async';
import 'dart:io';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

FutureOr<QueryExecutor> Function() pg(Iterable<String> schemas) {
  // Use single connection
  return () => connectToPostgres(schemas);

  // Use PostgreSqlExecutorPool (Not working)
  //return () => connectToPostgresPool1(schemas);
}

Future<void> closePg(QueryExecutor executor) async {
  if (executor is PostgreSqlExecutor) {
    await executor.close();
  }
}

Future<PostgreSqlExecutor> connectToPostgres(Iterable<String> schemas) async {
  // postgres://kfayrlbi:OAaEE39zOMLEPfH4DDgHbGNVsQtNdHu7@heffalump.db.elephantsql.com/kfayrlbi
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

Future<PostgreSqlPoolExecutor> connectToPostgresPool(
    Iterable<String> schemas) async {
  var dbPool = Pool.withEndpoints([
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: Platform.environment['POSTGRES_DB'] ?? 'orm_test',
      username: Platform.environment['POSTGRES_USERNAME'] ?? 'test',
      password: Platform.environment['POSTGRES_PASSWORD'] ?? 'test123',
    )
  ],
      settings: PoolSettings(
          maxConnectionAge: Duration(hours: 1), maxConnectionCount: 5));

  // Run sql to create the tables in a transaction
  await dbPool.runTx((conn) async {
    for (var s in schemas) {
      await conn.execute(await File('test/migrations/$s.sql').readAsString());
    }
  });

  return PostgreSqlPoolExecutor(dbPool, logger: Logger.root);
}
