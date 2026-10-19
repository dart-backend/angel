import 'dart:async';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql_dart/mysql_dart.dart';

import 'mysql_family.dart';
import 'sql_migration_runner.dart';

/// A migration runner of MySQL or MariaDB, of a [connection] of `mysql_dart`,
/// whose schemas are [S].
///
/// MySQL and MariaDB commit each change of a table on their own, so a
/// migration is recorded in the `migrations` table once it has run.
abstract class MySqlFamilyMigrationRunner<S extends MySqlFamilySchema>
    extends SqlMigrationRunner<S> {
  final MySQLConnection connection;

  MySqlFamilyMigrationRunner(
    this.connection,
    Logger log,
    Iterable<Migration> migrations,
  ) : super(log, migrations);

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
    'UPDATE migrations SET path = ? WHERE path = ?',
    [name, path],
  );

  @override
  Future<void> deletePath(String path) =>
      connection.execute('DELETE FROM migrations WHERE path = ?', [path]);

  @override
  String compileSchema(S schema) => schema.compile();

  @override
  Future<void> runAndRecord(S schema, String name, int batch) async {
    await schema.run(connection);
    await connection.execute(
      'INSERT INTO migrations (batch, path) VALUES (?, ?)',
      [batch, name],
    );
  }

  @override
  Future<void> runAndRemove(S schema, String name) async {
    await schema.run(connection);
    await deletePath(name);
  }

  @override
  Future close() => connection.close();
}
