import 'dart:async';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:postgres/postgres.dart';
import 'package:logging/logging.dart';

import '../sql_migration_runner.dart';
import 'schema.dart';

/// A PostgreSQL database migration runner
///
/// Each migration is run, and recorded in the `migrations` table, in one
/// transaction, as PostgreSQL changes its tables in one, so that a migration
/// that fails, or is cut off, is neither run nor recorded.
class PostgresMigrationRunner extends SqlMigrationRunner {
  final Connection connection;

  PostgresMigrationRunner(
    this.connection, {
    Iterable<Migration> migrations = const [],
    bool connected = false,
  }) : super(Logger('PostgresMigrationRunner'), migrations);

  @override
  Future<void> createMigrationsTable() async {
    if (!connection.isOpen) {
      throw Exception("PostgreSQL connection is not open");
    }
    await connection.execute('''
    CREATE TABLE IF NOT EXISTS "migrations" (
      id serial,
      batch integer,
      path varchar(500),
      PRIMARY KEY(id)
    );
    ''');
  }

  @override
  Future<List<Object?>> queryColumn(String sql) async => [
    for (var row in await connection.execute(sql)) row[0],
  ];

  @override
  Future<void> renamePath(String path, String name) => connection.execute(
    Sql.named('UPDATE migrations SET path = @name WHERE path = @path'),
    parameters: {'name': name, 'path': path},
  );

  @override
  Future<void> deletePath(String path) => _deletePath(connection, path);

  Future<void> _deletePath(Session session, String path) => session.execute(
    Sql.named('DELETE FROM migrations WHERE path = @path'),
    parameters: {'path': path},
  );

  @override
  Future<void> runUp(String name, Migration migration, int batch) async {
    var schema = PostgresSchema();
    migration.up(schema);
    await connection.runTx((ctx) async {
      await _run(ctx, schema);
      await ctx.execute(
        Sql.named(
          'INSERT INTO migrations (batch, path) VALUES (@batch, @path)',
        ),
        parameters: {'batch': batch, 'path': name},
      );
    });
  }

  @override
  Future<void> runDown(String name, Migration migration) async {
    var schema = PostgresSchema();
    migration.down(schema);
    await connection.runTx((ctx) async {
      await _run(ctx, schema);
      await _deletePath(ctx, name);
    });
  }

  /// Runs the SQL of [schema] with the simple query protocol, as the
  /// extended one takes only one statement.
  Future<void> _run(Session session, PostgresSchema schema) async {
    var sql = schema.compile();
    if (sql.trim().isEmpty) return;
    await session.execute(sql, queryMode: QueryMode.simple);
  }

  @override
  String compileUp(Migration migration) {
    var schema = PostgresSchema();
    migration.up(schema);
    return schema.compile();
  }

  @override
  Future close() {
    return connection.close();
  }
}
