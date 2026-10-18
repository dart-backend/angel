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
class MariaDbMigrationRunner extends SqlMigrationRunner<MariaDbSchema> {
  final MySqlConnection connection;

  MariaDbMigrationRunner(
    this.connection, {
    Iterable<Migration> migrations = const [],
    @Deprecated('Not used: the connection is opened and closed by the caller.')
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
  MariaDbSchema newSchema() => MariaDbSchema();

  @override
  String compileSchema(MariaDbSchema schema) => schema.compile();

  @override
  Future<void> runRecorded(
    MariaDbSchema schema,
    String name, {
    int? batch,
  }) async {
    await schema.run(connection);
    if (batch == null) {
      await deletePath(name);
    } else {
      await connection.query(
        'INSERT INTO migrations (batch, path) VALUES (?, ?)',
        [batch, name],
      );
    }
  }

  @override
  Future close() {
    return connection.close();
  }
}
