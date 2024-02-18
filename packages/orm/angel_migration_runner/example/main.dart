import 'dart:io';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';

import 'todo.dart';

void main(List<String> args) async {
  var host = Platform.environment['DB_HOST'] ?? 'localhost';
  var database = Platform.environment['DB_NAME'] ?? 'demo';
  var username = Platform.environment['DB_USERNAME'] ?? 'demouser';
  var password = Platform.environment['DB_PASSWORD'] ?? 'demo123';

  print("$host $database $username $password");

  Connection conn = await Connection.open(Endpoint(
      host: host,
      port: 5432,
      database: database,
      username: username,
      password: password));

  var postgresqlMigrationRunner = PostgresMigrationRunner(
    conn,
    migrations: [
      UserMigration(),
      TodoMigration(),
      FooMigration(),
    ],
  );

  /*
  var mySQLConn = await MySQLConnection.createConnection(
      host: host,
      port: 3306,
      databaseName: database,
      userName: username,
      password: password,
      secure: false);

  // ignore: unused_local_variable
  var mysqlMigrationRunner = MySqlMigrationRunner(
    mySQLConn,
    migrations: [
      UserMigration(),
      TodoMigration(),
      FooMigration(),
    ],
  );
  */

  runMigrations(postgresqlMigrationRunner, args);
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
