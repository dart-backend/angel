import 'dart:io';

import 'package:mysql_dart/mysql_dart.dart';

/// Why the tests on PostgreSQL are skipped, or `null` if it can be reached at
/// `POSTGRES_HOST` (default `localhost`), port 5432.
Future<String?> skipUnlessPostgres() =>
    _skipUnlessReachable('PostgreSQL', 'POSTGRES_HOST', 5432);

/// Why the tests on MySQL or MariaDB are skipped, or `null` if it can be
/// reached at `MYSQL_HOST` (default `localhost`), port 3306.
Future<String?> skipUnlessMySql() =>
    _skipUnlessReachable('MySQL/MariaDB', 'MYSQL_HOST', 3306);

/// Only whether the database can be reached, so that a database that rejects
/// the tests' settings, such as their password, still fails them.
Future<String?> _skipUnlessReachable(
  String database,
  String hostVariable,
  int port,
) async {
  var host = Platform.environment[hostVariable] ?? 'localhost';
  try {
    var socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
    return null;
  } on SocketException {
    return '$database cannot be reached at $host:$port; '
        'set $hostVariable to its host';
  }
}

/// A connection to the MySQL or MariaDB of the tests, of `MYSQL_HOST`,
/// `MYSQL_DB`, `MYSQL_USERNAME` and `MYSQL_PASSWORD`.
///
/// It uses TLS unless `MYSQL_SECURE` is `false`. The server's certificate is
/// only verified if `MYSQL_VERIFY_CERTIFICATE` is `true`, as a local server,
/// such as one in Docker, has the self-signed certificate MySQL and MariaDB
/// generate, which `mysql_dart` 4 rejects by default.
Future<MySQLConnection> openMySqlConnection() async {
  var connection = await MySQLConnection.createConnection(
    host: Platform.environment['MYSQL_HOST'] ?? 'localhost',
    port: 3306,
    databaseName: Platform.environment['MYSQL_DB'] ?? 'orm_test',
    userName: Platform.environment['MYSQL_USERNAME'] ?? 'test',
    password: Platform.environment['MYSQL_PASSWORD'] ?? 'Test123',
    secure: Platform.environment['MYSQL_SECURE'] != 'false',
    verifyServerCertificate:
        Platform.environment['MYSQL_VERIFY_CERTIFICATE'] == 'true',
  );
  await connection.connect();
  return connection;
}
