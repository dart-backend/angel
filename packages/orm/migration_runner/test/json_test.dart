import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/mariadb.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_migration_runner/sqlite.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

/// `ColumnType.json` and `ColumnType.jsonb`, as each database declares them.
void main() {
  var json = MigrationColumn(ColumnType.json);
  var jsonb = MigrationColumn(ColumnType.jsonb);

  test('PostgreSQL: json and jsonb', () {
    expect(PostgresGenerator.columnType(json), 'json');
    expect(PostgresGenerator.columnType(jsonb), 'jsonb');
  });

  test('MySQL and MariaDB: json, which has no jsonb', () {
    for (var columnType in [
      MySqlGenerator.columnType,
      MariaDbGenerator.columnType,
    ]) {
      expect(columnType(json), 'json');
      expect(columnType(jsonb), 'json');
    }
  });

  test('SQLite: TEXT', () {
    expect(SqliteGenerator.columnType(json), 'TEXT');
    expect(SqliteGenerator.columnType(jsonb), 'TEXT');
  });
}
