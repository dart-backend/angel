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
  var host = Platform.environment['POSTGRES_HOST'] ?? 'localhost';
  var database = Platform.environment['POSTGRES_DB'] ?? 'orm_test';
  var username = Platform.environment['POSTGRES_USERNAME'] ?? 'test';
  var password = Platform.environment['POSTGRES_PASSWORD'] ?? 'test123';

  var conn = await Connection.open(
    Endpoint(
      host: host,
      port: 5432,
      database: database,
      username: username,
      password: password,
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  // Run sql to create the tables
  for (var s in schemas) {
    var rawQueryString = await File('test/migrations/$s.sql').readAsString();
    print("Raw SQL Query: $rawQueryString");
    //await conn.execute(queryString);

    // Split the queries and execute them
    var stringLen = rawQueryString.length;
    var index = 0;
    while (index < stringLen) {
      index = rawQueryString.indexOf(";");
      if (index < 0) {
        break;
      }
      var query = rawQueryString.substring(0, index);
      print("SQL Query: $query;");
      await conn.execute("$query;");

      index++;
      if (index < stringLen) {
        var tempString = rawQueryString.substring(index).trim();
        rawQueryString = tempString;
        stringLen = rawQueryString.length;
        index = 0;
      }
    }
    /*
    var queryString = rawQueryString.replaceAll("\n", " ");
    print("Raw Query: $queryString");
    var queries = queryString.split(';');
    for (var rawQuery in queries) {
      var query = rawQuery.trim();
      if (query.isNotEmpty) {
        print("SQL Query: $query;");
        await conn.execute("$query;");
      }
    }
    */
  }

  return PostgreSqlExecutor(conn, logger: Logger.root);
}

Future<PostgreSqlPoolExecutor> connectToPostgresPool(
  Iterable<String> schemas,
) async {
  var dbPool = Pool.withEndpoints(
    [
      Endpoint(
        host: 'localhost',
        port: 5432,
        database: Platform.environment['POSTGRES_DB'] ?? 'orm_test',
        username: Platform.environment['POSTGRES_USERNAME'] ?? 'test',
        password: Platform.environment['POSTGRES_PASSWORD'] ?? 'test123',
      ),
    ],
    settings: PoolSettings(
      maxConnectionAge: Duration(hours: 1),
      maxConnectionCount: 5,
      sslMode: SslMode.disable,
    ),
  );

  // Run sql to create the tables in a transaction
  await dbPool.runTx((conn) async {
    for (var s in schemas) {
      await conn.execute(await File('test/migrations/$s.sql').readAsString());
    }
  });

  return PostgreSqlPoolExecutor(dbPool, logger: Logger.root);
}
