import 'dart:async';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';

import '../sql_migration_runner.dart';
import 'schema.dart';

/// A MySQL database migration runner.
///
/// MySQL commits each change of a table on its own, so a migration is
/// recorded in the `migrations` table once it has run.
class MySqlMigrationRunner extends SqlMigrationRunner {
  final MySQLConnection connection;

  MySqlMigrationRunner(
    this.connection, {
    Iterable<Migration> migrations = const [],
    bool connected = false,
  }) : super(Logger('MysqlMigrationRunner'), migrations);

  @override
  Future<void> createMigrationsTable() async {
    await connection.execute('''
    CREATE TABLE IF NOT EXISTS migrations (
      id integer NOT NULL AUTO_INCREMENT,
      batch integer,
      path varchar(500),
      PRIMARY KEY(id)
    );
    ''');
  }

  @override
  Future<List<Object?>> queryColumn(String sql) async => [
    for (var row in (await connection.execute(sql)).rows) row.colAt(0),
  ];

  @override
  Future<void> renamePath(String path, String name) => connection.execute(
    'UPDATE migrations SET path = :name WHERE path = :path',
    {'name': name, 'path': path},
  );

  @override
  Future<void> deletePath(String path) => connection.execute(
    'DELETE FROM migrations WHERE path = :path',
    {'path': path},
  );

  @override
  Future<void> runUp(String name, Migration migration, int batch) async {
    var schema = MySqlSchema();
    migration.up(schema);
    await schema.run(connection);
    await connection.execute(
      'INSERT INTO migrations (batch, path) VALUES (:batch, :path)',
      {'batch': batch, 'path': name},
    );
  }

  @override
  Future<void> runDown(String name, Migration migration) async {
    var schema = MySqlSchema();
    migration.down(schema);
    await schema.run(connection);
    await deletePath(name);
  }

  @override
  String compileUp(Migration migration) {
    var schema = MySqlSchema();
    migration.up(schema);
    return schema.compile();
  }

  @override
  Future close() {
    return connection.close();
  }
}
