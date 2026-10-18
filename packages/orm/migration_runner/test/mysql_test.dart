import 'dart:io';

import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/mysql_todo.dart';

void main() async {
  var skip = await skipUnlessMySql();
  late MySQLConnection conn;
  late MigrationRunner runner;

  setUp(() async {
    print("Setup...");

    var host = Platform.environment['MYSQL_HOST'] ?? 'localhost';
    var database = Platform.environment['MYSQL_DB'] ?? 'orm_test';
    var username = Platform.environment['MYSQL_USERNAME'] ?? 'test';
    var password = Platform.environment['MYSQL_PASSWORD'] ?? 'Test123';
    //var secure = !('false' == Platform.environment['MYSQL_SECURE']);

    print("$host $database $username");

    conn = await MySQLConnection.createConnection(
      databaseName: database,
      port: 3306,
      host: host,
      userName: username,
      password: password,
      secure: true,
    );

    await conn.connect();

    runner = MySqlMigrationRunner(
      conn,
      migrations: [
        CarMigration(),
        UserMigration(),
        TodoMigration(),
        ItemMigration(),
      ],
    );
  });

  group('Mysql migrate tables', skip: skip, () {
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
          'INSERT INTO migrations (batch, path) VALUES (1, :path)',
          {'path': 'C:\\app\\lib\\todo.dart#$name'},
        );
      }
      try {
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
    if (conn.connected) {
      await conn.close();
    }
  });
}
