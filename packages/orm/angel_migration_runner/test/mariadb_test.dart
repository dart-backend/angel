import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:test/test.dart';

void main() async {
  late MySqlConnection conn;

  setUp(() async {
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
  });

  group('MariaDB', () {
    test('migrate tables', () async {});
  });

  tearDown(() async {
    await conn.close();
  });
}
