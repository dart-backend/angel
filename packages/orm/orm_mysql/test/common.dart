import 'dart:async';
import 'dart:io';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:logging/logging.dart';
import 'package:mysql_dart/mysql_dart.dart';

// MySQL and MariaDB has some differences in the ordering of the results
// Update this according to either 'mysql' or 'mariadb'
const targetTestDatabase = 'mariadb';

// For MySQL/MariaDB using `mysql_dart` driver
Future<MySQLConnection> openMySqlConnection() async {
  var connection = await MySQLConnection.createConnection(
    databaseName: Platform.environment['MYSQL_DB'] ?? 'orm_test',
    port: int.parse(Platform.environment['MYSQL_PORT'] ?? '3306'),
    host: Platform.environment['MYSQL_HOST'] ?? 'localhost',
    userName: Platform.environment['MYSQL_USERNAME'] ?? 'test',
    password: Platform.environment['MYSQL_PASSWORD'] ?? 'Test123',
    secure: !('false' == Platform.environment['MYSQL_SECURE']),
  );

  await connection.connect(timeoutMs: 10000);

  return connection;
}

// For MariaDB, which stores a `DateTime` as UTC
Future<MariaDbExecutor> openMariaDbExecutor() async =>
    MariaDbExecutor(await openMySqlConnection(), logger: Logger('orm_mariadb'));

Future<QueryExecutor> createExecutor(MySQLConnection conn) async {
  var logger = Logger('orm_mysql');

  return MySqlExecutor(conn, logger: logger);
}

Future<MigrationRunner> createTables(
  MySQLConnection conn,
  List<Migration> models,
) async {
  var runner = MySqlMigrationRunner(conn, migrations: models);
  await runner.up();

  return runner;
}

Future<void> dropTables(MigrationRunner runner) async {
  await runner.reset();
}
