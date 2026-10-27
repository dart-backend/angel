import 'dart:async';
import 'dart:io';

import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:postgres/postgres.dart';

/// Connects to PostgreSQL with the settings the tests use, from the
/// environment: `POSTGRES_HOSTNAME` (default `localhost`), `POSTGRES_DB`,
/// `POSTGRES_USERNAME` and `POSTGRES_PASSWORD` (each `postgres` by default).
///
/// SSL is not used, as for a local server; set `POSTGRES_SSL=true` to require
/// it.
Future<Connection> dbConnection() async {
  var env = Platform.environment;
  return Connection.open(
    Endpoint(
      host: env['POSTGRES_HOSTNAME'] ?? 'localhost',
      port: 5432,
      database: env['POSTGRES_DB'] ?? 'postgres',
      username: env['POSTGRES_USERNAME'] ?? 'postgres',
      password: env['POSTGRES_PASSWORD'] ?? 'postgres',
    ),
    settings: ConnectionSettings(
      sslMode: env['POSTGRES_SSL'] == 'true'
          ? SslMode.require
          : SslMode.disable,
    ),
  );
}

Future<PostgreSqlExecutor> connect() async {
  final conn = await dbConnection();

  var executor = PostgreSqlExecutor(conn);
  return executor;
}
