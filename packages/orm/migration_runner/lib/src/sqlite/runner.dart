import 'dart:async';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart';

import '../sql_migration_runner.dart';
import 'schema.dart';

/// A SQLite database migration runner, of a database of the `sqlite3`
/// package.
///
/// Each migration is run, and recorded in the `migrations` table, in one
/// savepoint, as SQLite changes its tables in a transaction, so that a
/// migration that fails is neither run nor recorded. It is a transaction of
/// its own, or a part of the one the database is in.
class SqliteMigrationRunner extends SqlMigrationRunner<SqliteSchema> {
  final CommonDatabase database;

  SqliteMigrationRunner(
    this.database, {
    Iterable<Migration> migrations = const [],
  }) : super(Logger('SqliteMigrationRunner'), migrations);

  @override
  Future<void> createMigrationsTable() async {
    database.execute('''
    CREATE TABLE IF NOT EXISTS "migrations" (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      batch INTEGER,
      path VARCHAR(500)
    );
    ''');
  }

  @override
  Future<List<Object?>> queryColumn(String sql) async => [
    for (var row in database.select(sql).rows) row.first,
  ];

  @override
  Future<void> renamePath(String path, String name) async => database.execute(
    'UPDATE migrations SET path = ? WHERE path = ?',
    [name, path],
  );

  @override
  Future<void> deletePath(String path) async =>
      database.execute('DELETE FROM migrations WHERE path = ?', [path]);

  @override
  SqliteSchema newSchema() => SqliteSchema();

  @override
  String compileSchema(SqliteSchema schema) => schema.compile();

  @override
  Future<void> runAndRecord(SqliteSchema schema, String name, int batch) =>
      _inSavepoint(() {
        schema.run(database);
        database.execute('INSERT INTO migrations (batch, path) VALUES (?, ?)', [
          batch,
          name,
        ]);
      });

  @override
  Future<void> runAndRemove(SqliteSchema schema, String name) =>
      _inSavepoint(() {
        schema.run(database);
        database.execute('DELETE FROM migrations WHERE path = ?', [name]);
      });

  /// Runs [f] in a savepoint, which is rolled back if it throws.
  Future<void> _inSavepoint(void Function() f) async {
    database.execute('SAVEPOINT angel3_migration');
    try {
      f();
      database.execute('RELEASE angel3_migration');
    } catch (_) {
      // SQLite may have rolled back the transaction already, as of some
      // errors, and the savepoint with it.
      if (!database.autocommit) {
        database.execute('ROLLBACK TO angel3_migration');
        database.execute('RELEASE angel3_migration');
      }
      rethrow;
    }
  }

  /// Closes the database.
  @override
  Future close() async => database.close();
}
