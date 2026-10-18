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
class MySqlMigrationRunner extends SqlMigrationRunner<MySqlSchema> {
  final MySQLConnection connection;

  MySqlMigrationRunner(
    this.connection, {
    Iterable<Migration> migrations = const [],
    @Deprecated('Not used: the connection is opened and closed by the caller.')
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
  MySqlSchema newSchema() => MySqlSchema();

  @override
  String compileSchema(MySqlSchema schema) => schema.compile();

  @override
  Future<void> runRecorded(
    MySqlSchema schema,
    String name, {
    int? batch,
  }) async {
    await schema.run(connection);
    if (batch == null) {
      await deletePath(name);
    } else {
      await connection.execute(
        'INSERT INTO migrations (batch, path) VALUES (:batch, :path)',
        {'batch': batch, 'path': name},
      );
    }
  }

  @override
  Future close() {
    return connection.close();
  }
}
