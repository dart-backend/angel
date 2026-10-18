import 'dart:async';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';

import '../sql_migration_runner.dart';
import 'schema.dart';

/// A MariaDB database migration runner.
///
/// MariaDB commits each change of a table on its own, so a migration is
/// recorded in the `migrations` table once it has run.
class MariaDbMigrationRunner extends SqlMigrationRunner {
  final MySqlConnection connection;

  MariaDbMigrationRunner(
    this.connection, {
    Iterable<Migration> migrations = const [],
    bool connected = true,
  }) : super(Logger('MariaDbMigrationRunner'), migrations);

  @override
  Future<void> createMigrationsTable() async {
    await connection.query('''
    CREATE TABLE IF NOT EXISTS migrations (
      id integer NOT NULL AUTO_INCREMENT,
      batch integer,
      path varchar(500),
      PRIMARY KEY(id)
    );
    ''');
  }

  /// The values of the first column of [sql], which `mysql1` may give as a
  /// `Blob`.
  @override
  Future<List<Object?>> queryColumn(String sql) async => [
    for (var row in await connection.query(sql)) row[0],
  ];

  @override
  Future<void> renamePath(String path, String name) => connection.query(
    'UPDATE migrations SET path = ? WHERE path = ?',
    [name, path],
  );

  @override
  Future<void> deletePath(String path) =>
      connection.query('DELETE FROM migrations WHERE path = ?', [path]);

  @override
  Future<void> runUp(String name, Migration migration, int batch) async {
    var schema = MariaDbSchema();
    migration.up(schema);
    await schema.run(connection);
    await connection.query(
      'INSERT INTO migrations (batch, path) VALUES (?, ?)',
      [batch, name],
    );
  }

  @override
  Future<void> runDown(String name, Migration migration) async {
    var schema = MariaDbSchema();
    migration.down(schema);
    await schema.run(connection);
    await deletePath(name);
  }

  @override
  String compileUp(Migration migration) {
    var schema = MariaDbSchema();
    migration.up(schema);
    return schema.compile();
  }

  @override
  Future close() {
    return connection.close();
  }
}
