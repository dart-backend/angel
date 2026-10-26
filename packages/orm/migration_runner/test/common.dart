import 'dart:io';

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
