import 'dart:io';

import 'package:postgres/postgres.dart';

/// A connection to the PostgreSQL server of the tests, of `POSTGRES_HOST`
/// (or `POSTGRES_HOSTNAME`), `POSTGRES_PORT`, `POSTGRES_DB`,
/// `POSTGRES_USERNAME` and `POSTGRES_PASSWORD`; by default `localhost:5432`,
/// database `postgres`, `postgres`/`postgres`.
Future<Connection> openPgConnection() {
  var env = Platform.environment;
  return Connection.open(
    Endpoint(
      host: env['POSTGRES_HOST'] ?? env['POSTGRES_HOSTNAME'] ?? 'localhost',
      port: int.parse(env['POSTGRES_PORT'] ?? '5432'),
      database: env['POSTGRES_DB'] ?? 'postgres',
      username: env['POSTGRES_USERNAME'] ?? 'postgres',
      password: env['POSTGRES_PASSWORD'] ?? 'postgres',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );
}
