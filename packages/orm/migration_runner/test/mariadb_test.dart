import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/mariadb.dart';
import 'package:mysql_dart/mysql_dart.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/mysql_todo.dart';

void main() async {
  var skip = await skipUnlessMySql();
  late MySQLConnection conn;
  late MigrationRunner runner;

  setUp(() async {
    print("Setup...");

    conn = await openMySqlConnection();

    runner = MariaDbMigrationRunner(
      conn,
      migrations: [
        CarMigration(),
        UserMigration(),
        TodoMigration(),
        ItemMigration(),
      ],
    );
  });

  group('MariaDB migrate tables', skip: skip, () {
    test('up', () async {
      print("Test migration up");
      await runner.up();
    });

    test('reset', () async {
      print("Test migration reset");
      await runner.reset();
    });

    test('up renames the paths of earlier versions', () async {
      var names = [
        'CarMigration',
        'UserMigration',
        'TodoMigration',
        'ItemMigration',
      ];
      for (var name in names) {
        await conn.execute(
          'INSERT INTO migrations (batch, path) VALUES (1, ?)',
          ['C:\\app\\lib\\todo.dart#$name'],
        );
      }
      // Recorded again after the project was moved, so which of them is
      // that of UserMigration cannot be told, as it has no legacyPath.
      await conn.execute(
        "INSERT INTO migrations (batch, path) "
        "VALUES (1, '/moved/lib/todo.dart#UserMigration')",
      );
      try {
        await expectLater(runner.up(), throwsStateError);
        await conn.execute(
          "DELETE FROM migrations WHERE path = '/moved/lib/todo.dart#UserMigration'",
        );
        await runner.up();
        var r = await conn.execute('SELECT path FROM migrations;');
        expect(r.rows.map((row) => row.colAt(0)), unorderedEquals(names));
      } finally {
        await conn.execute('DELETE FROM migrations;');
      }
    });
  });

  tearDown(() async {
    print("Teardown...");
    await conn.close();
  });
}
