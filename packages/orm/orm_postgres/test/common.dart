import 'dart:async';
import 'dart:io';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

List tmpTables = [];

// For PostgreSQL
/// The PostgreSQL server of the tests, of the environment variables
/// `POSTGRES_HOST` (or `POSTGRES_HOSTNAME`), `POSTGRES_PORT`, `POSTGRES_DB`,
/// `POSTGRES_USERNAME` and `POSTGRES_PASSWORD`, as CI sets them; by default,
/// `localhost:5432`, database `postgres`, user `postgres`/`postgres`. An empty
/// variable is taken as unset.
///
/// A setting that cannot be right throws, rather than fall back to the
/// default server, whose tables the tests would create and drop.
Endpoint pgEndpoint() {
  String? env(String name) {
    var value = Platform.environment[name];
    return value == null || value.isEmpty ? null : value;
  }

  var host = env('POSTGRES_HOST');
  var hostname = env('POSTGRES_HOSTNAME');
  if (host != null && hostname != null && host != hostname) {
    throw StateError(
      'POSTGRES_HOST ($host) and POSTGRES_HOSTNAME ($hostname) differ.',
    );
  }

  var port = env('POSTGRES_PORT');
  return Endpoint(
    host: host ?? hostname ?? 'localhost',
    port: port == null
        ? 5432
        : switch (int.tryParse(port)) {
            var number? when number > 0 && number < 65536 => number,
            _ => throw StateError('POSTGRES_PORT ($port) is not a port.'),
          },
    database: env('POSTGRES_DB') ?? 'postgres',
    username: env('POSTGRES_USERNAME') ?? 'postgres',
    password: env('POSTGRES_PASSWORD') ?? 'postgres',
  );
}

Future<Connection> openPgConnection() => Connection.open(
  pgEndpoint(),
  settings: ConnectionSettings(sslMode: SslMode.disable),
);

Future<QueryExecutor> createExecutor(Connection conn) async {
  var logger = Logger('orm_postgres');

  return PostgreSqlExecutor(conn, logger: logger);
}

Future<MigrationRunner> createTables(
  Connection conn,
  List<Migration> models,
) async {
  var runner = PostgresMigrationRunner(conn, migrations: models);
  await runner.up();

  return runner;
}

Future<void> dropTables(MigrationRunner runner) async {
  await runner.reset();
}

String extractTableName(String createQuery) {
  var start = createQuery.indexOf('EXISTS');
  var end = createQuery.indexOf('(');

  if (start == -1 || end == -1) {
    return '';
  }

  return createQuery.substring(start + 6, end).trim();
}
