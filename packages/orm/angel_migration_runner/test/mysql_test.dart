import 'dart:io';

import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';

void main() async {
  late MySQLConnection conn;

  setUp(() async {
    var host = Platform.environment['MYSQL_HOST'] ?? 'localhost';
    var database = Platform.environment['MYSQL_DB'] ?? 'orm_test';
    var username = Platform.environment['MYSQL_USERNAME'] ?? 'test';
    var password = Platform.environment['MYSQL_PASSWORD'] ?? 'test123';
    var secure = !('false' == Platform.environment['MYSQL_SECURE']);

    print("$host $database $username $password $secure");

    conn = await MySQLConnection.createConnection(
        databaseName: database,
        port: 3306,
        host: host,
        userName: username,
        password: password,
        secure: secure);
  });

  group('Mysql', () {
    test('migrate tables', () async {});
  });

  tearDown(() async {
    await conn.close();
  });
}
