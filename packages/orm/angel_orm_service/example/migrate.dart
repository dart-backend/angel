import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'connect.dart';
import 'todo.dart';

Future main(List<String> args) {
  var runner = PostgresMigrationRunner(conn, migrations: [
    TodoMigration(),
  ]);
  return runMigrations(runner, args);
}
