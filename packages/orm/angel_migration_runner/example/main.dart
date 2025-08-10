import 'dart:io';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:postgres/postgres.dart';

import 'todo.dart';

void main(List<String> args) async {
  // Run migration on PostgreSQL database
  postgresqlMigration(args);

  // Run migration on MySQL database
  mysqlMigration(args);
}

void postgresqlMigration(List<String> args) async {
  var host = Platform.environment['DB_HOST'] ?? 'localhost';
  var database = Platform.environment['DB_NAME'] ?? 'demo';
  var username = Platform.environment['DB_USERNAME'] ?? 'demouser';
  var password = Platform.environment['DB_PASSWORD'] ?? 'demo123';

  print("$host $database $username $password");

  Connection conn = await Connection.open(
    Endpoint(
      host: host,
      port: 5432,
      database: database,
      username: username,
      password: password,
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  var runner = PostgresMigrationRunner(
    conn,
    migrations: [UserMigration(), TodoMigration(), FooMigration()],
  );

  runMigrations(runner, args);
}

void mysqlMigration(List<String> args) async {
  var host = Platform.environment['MYSQL_HOST'] ?? 'localhost';
  var database = Platform.environment['MYSQL_DB'] ?? 'orm_test';
  var username = Platform.environment['MYSQL_USERNAME'] ?? 'test';
  var password = Platform.environment['MYSQL_PASSWORD'] ?? 'test123';

  var mySQLConn = await MySQLConnection.createConnection(
    host: host,
    port: 3306,
    databaseName: database,
    userName: username,
    password: password,
    secure: true,
  );

  // ignore: unused_local_variable
  var runner = MySqlMigrationRunner(
    mySQLConn,
    migrations: [UserMigration(), TodoMigration(), FooMigration()],
  );

  runMigrations(runner, args);
}

class FooMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('foos', (table) {
      table
        ..serial('id').primaryKey()
        ..varChar('bar', length: 64)
        ..timeStamp('created_at').defaultsTo(currentTimestamp);
    });
  }

  @override
  void down(Schema schema) => schema.drop('foos');
}
