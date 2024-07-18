import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

void main() async {
  late Connection conn;

  setUp(() async {
    var host = Platform.environment['POSTGRES_HOST'] ?? 'localhost';
    var database = Platform.environment['POSTGRES_DB'] ?? 'orm_test';
    var username = Platform.environment['POSTGRES_USERNAME'] ?? 'test';
    var password = Platform.environment['POSTGRES_PASSWORD'] ?? 'test123';

    print("$host $database $username $password");

    conn = await Connection.open(Endpoint(
        host: host,
        port: 5432,
        database: database,
        username: username,
        password: password));
  });

  group('PostgreSQL', () {
    test('migrate tables', () async {});
  });

  tearDown(() async {
    await conn.close();
  });
}
