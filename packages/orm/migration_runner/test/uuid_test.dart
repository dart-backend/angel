import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/mariadb.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_migration_runner/sqlite.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

/// `ColumnType.uuid`, as each database declares it.
void main() {
  var key = MigrationColumn(
    ColumnType.uuid,
    isNullable: false,
    indexType: IndexType.primaryKey,
  );
  var foreign = MigrationColumn(ColumnType.uuid);

  test('PostgreSQL: uuid', () {
    expect(PostgresGenerator.columnType(foreign), 'uuid');
    expect(PostgresGenerator.compileColumn(key), 'uuid NOT NULL PRIMARY KEY');
  });

  test(
    'MySQL and MariaDB: char(36) of a binary collation, not AUTO_INCREMENT',
    () {
      for (var columnType in [
        MySqlGenerator.columnType,
        MariaDbGenerator.columnType,
      ]) {
        expect(
          columnType(foreign),
          'char(36) CHARACTER SET ascii COLLATE ascii_bin',
        );
      }
      for (var compileColumn in [
        MySqlGenerator.compileColumn,
        MariaDbGenerator.compileColumn,
      ]) {
        expect(
          compileColumn(key),
          'char(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY',
        );
      }
    },
  );

  test('SQLite: TEXT', () {
    expect(SqliteGenerator.columnType(foreign), 'TEXT');
    expect(SqliteGenerator.columnType(key), 'TEXT');
  });
}
