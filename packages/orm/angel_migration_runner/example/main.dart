import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:angel3_migration_runner/mysql.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';
import 'package:mysql1/mysql1.dart';

import 'todo.dart';

var postgresqlMigrationRunner = PostgresMigrationRunner(
  PostgreSQLConnection('127.0.0.1', 5432, 'demo',
      username: 'demouser', password: 'demo123'),
  migrations: [
    UserMigration(),
    TodoMigration(),
    FooMigration(),
  ],
);

var mysqlMigrationRunner = MysqlMigrationRunner(
  ConnectionSettings(
      host: 'localhost',
      port: 3306,
      user: 'demouser',
      password: 'demo123',
      db: 'demo'),
  migrations: [
    UserMigration(),
    TodoMigration(),
    FooMigration(),
  ],
);

void main(List<String> args) => runMigrations(postgresqlMigrationRunner, args);

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
