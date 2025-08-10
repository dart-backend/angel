import 'dart:async';
import 'dart:io';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
import 'package:logging/logging.dart';
//import 'package:mysql1/mysql1.dart';
import 'package:mysql_client/mysql_client.dart';

List tmpTables = [];

// MySQL and MariaDB has some differences in the ordering of the results
// Update this according to either 'mysql' or 'mariadb'
const TARGET_TEST_DATABASE = 'mariadb';

// For MySQL/MariaDB using `mysql_client` driver
Future<MySQLConnection> openMySqlConnection() async {
  var connection = await MySQLConnection.createConnection(
    databaseName: 'orm_test',
    port: 3306,
    host: "localhost",
    userName: Platform.environment['MYSQL_USERNAME'] ?? 'test',
    password: Platform.environment['MYSQL_PASSWORD'] ?? 'Test123',
    secure: !('false' == Platform.environment['MYSQL_SECURE']),
  );

  await connection.connect(timeoutMs: 10000);

  return connection;
}

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

// For MariaDB
Future<void> dropTables2(QueryExecutor executor) {
  var sqlExecutor = (executor as MariaDbExecutor);
  for (var tableName in tmpTables.reversed) {
    print('DROP TABLE $tableName');
    sqlExecutor.query(tableName, 'DROP TABLE $tableName', {});
  }
  return sqlExecutor.close();
}

String extractTableName(String createQuery) {
  var start = createQuery.indexOf('EXISTS');
  var end = createQuery.indexOf('(');

  if (start == -1 || end == -1) {
    return '';
  }

  return createQuery.substring(start + 6, end).trim();
}

// Executor for MySQL/MariaDB using `mysql1` driver
/* Future<MariaDbExecutor> _connectToMysqlDb(List<String> schemas) async {
  var settings = ConnectionSettings(
      host: 'localhost',
      port: 3306,
      db: 'orm_test',
      user: 'test',
      password: 'test123');
  var connection = await MySqlConnection.connect(settings);

  var logger = Logger('orm_mariadb');

  tmpTables.clear();

  for (var s in schemas) {
    // MySQL driver does not support multiple sql queries
    var data = await File('test/migrations/$s.sql').readAsString();
    var queries = data.split(";");
    for (var q in queries) {
      print("Table: [$q]");
      if (q.trim().isNotEmpty) {
        //await connection.execute(q);
        await connection.query(q);

        var tableName = extractTableName(q);
        if (tableName != '') {
          tmpTables.add(tableName);
        }
      }
    }
  }

  return MysqlDbExecutor(connection, logger: logger);
} 
*/

/*
// Executor for MySQL
//   create user 'test'@'localhost' identified by 'test123';
//   GRANT ALL PRIVILEGES ON orm_test.* to 'test'@'localhost' WITH GRANT OPTION;
Future<MySqlExecutor> _connectToMySql(List<Migration> models) async {
  var connection = await MySQLConnection.createConnection(
      databaseName: 'orm_test',
      port: 3306,
      host: "localhost",
      userName: Platform.environment['MYSQL_USERNAME'] ?? 'test',
      password: Platform.environment['MYSQL_PASSWORD'] ?? 'test123',
      secure: !('false' == Platform.environment['MYSQL_SECURE']));

  await connection.connect(timeoutMs: 10000);

  var logger = Logger('orm_mysql');

  tmpTables.clear();

  var runner = MySqlMigrationRunner(connection, migrations: models);
  await runner.up();

  for (var s in schemas) {
    // MySQL driver does not support multiple sql queries
    var data = await File('test/migrations/$s.sql').readAsString();
    var queries = data.split(";");
    for (var q in queries) {
      //print("Table: [$q]");
      if (q.trim().isNotEmpty) {
        await connection.execute(q);

        var tableName = extractTableName(q);
        if (tableName != '') {
          tmpTables.add(tableName);
        }
      }
    }
  }

  return MySqlExecutor(connection, logger: logger);
}
*/
