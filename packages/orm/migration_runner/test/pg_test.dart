import 'dart:io';

import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/pg_todo.dart';

void main() async {
  var skip = await skipUnlessPostgres();
  late Connection conn;
  late MigrationRunner runner;

  setUp(() async {
    print("Setup...");

    var host = Platform.environment['POSTGRES_HOST'] ?? 'localhost';
    var database = Platform.environment['POSTGRES_DB'] ?? 'orm_test';
    var username = Platform.environment['POSTGRES_USERNAME'] ?? 'test';
    var password = Platform.environment['POSTGRES_PASSWORD'] ?? 'test123';

    //print("$host $database $username $password");

    conn = await Connection.open(
      Endpoint(
        host: host,
        port: 5432,
        database: database,
        username: username,
        password: password,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    runner = PostgresMigrationRunner(
      conn,
      migrations: [
        CarMigration(),
        UserMigration(),
        TodoMigration(),
        ItemMigration(),
      ],
    );
  });

  group('PostgreSQL migrate tables', skip: skip, () {
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
          Sql.named('INSERT INTO migrations (batch, path) VALUES (1, @path)'),
          parameters: {'path': 'C:\\\\app\\\\lib\\\\todo.dart#$name'},
        );
      }
      // Recorded again after the project was moved.
      await conn.execute(
        "INSERT INTO migrations (batch, path) "
        "VALUES (1, '/moved/lib/todo.dart#UserMigration')",
      );
      try {
        await runner.up();
        var r = await conn.execute('SELECT path FROM migrations;');
        expect(r.expand((x) => x), unorderedEquals(names));
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
