import 'dart:io';

import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/mariadb.dart';
import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

import 'models/mysql_todo.dart';

void main() async {
  late MySqlConnection conn;
  late MigrationRunner runner;

  setUp(() async {
    print("Setup...");

    var host = Platform.environment['MYSQL_HOST'] ?? 'localhost';
    var database = Platform.environment['MYSQL_DB'] ?? 'orm_test';
    var username = Platform.environment['MYSQL_USERNAME'] ?? 'test';
    var password = Platform.environment['MYSQL_PASSWORD'] ?? 'test123';

    var settings = ConnectionSettings(
        host: host,
        port: 3306,
        db: database,
        user: username,
        password: password);
    conn = await MySqlConnection.connect(settings);

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

  group('MariaDB migrate tables', () {
    test('up', () async {
      print("Test migration up");
      await runner.up();
    });

    test('reset', () async {
      print("Test migration reset");
      await runner.reset();
    });
  });

  tearDown(() async {
    print("Teardown...");
    await conn.close();
  });
}
