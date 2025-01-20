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
Future<Connection> openPgConnection() async {
  final connection = await Connection.open(
      Endpoint(
          host: Platform.environment['POSTGRES_HOSTNAME'] ?? 'localhost',
          port: 5432,
          database: Platform.environment['POSTGRES_DB'] ?? 'postgres',
          username: Platform.environment['POSTGRES_USERNAME'] ?? 'postgres',
          password: Platform.environment['POSTGRES_PASSWORD'] ?? 'postgres'),
      settings: ConnectionSettings(sslMode: SslMode.disable));

  return connection;
}

Future<QueryExecutor> createExecutor(Connection conn) async {
  var logger = Logger('orm_postgres');

  return PostgreSqlExecutor(conn, logger: logger);
}

Future<MigrationRunner> createTables(
    Connection conn, List<Migration> models) async {
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
