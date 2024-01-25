import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';
import 'package:mysql_client/mysql_client.dart';

import 'todo.dart';

void main(List<String> args) async {
  Connection conn = await Connection.open(Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'demo',
      username: 'demouser',
      password: 'demo123'));

  var postgresqlMigrationRunner = PostgresMigrationRunner(
    conn,
    migrations: [
      UserMigration(),
      TodoMigration(),
      FooMigration(),
    ],
  );

  var mySQLConn = await MySQLConnection.createConnection(
      host: "localhost",
      port: 3306,
      databaseName: "orm_test",
      userName: "test",
      password: "Test123*",
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
