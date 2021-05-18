import 'dart:async';
import 'package:args/command_runner.dart';
import 'runner.dart';

/// Runs the Angel Migration CLI.
Future runMigrations(MigrationRunner migrationRunner, List<String> args) {
  var cmd = CommandRunner('migration_runner', 'Executes Angel migrations.')
    ..addCommand(_UpCommand(migrationRunner))
    ..addCommand(_RefreshCommand(migrationRunner))
    ..addCommand(_ResetCommand(migrationRunner))
    ..addCommand(_RollbackCommand(migrationRunner));
  return cmd.run(args).then((_) => migrationRunner.close());
}

class _UpCommand extends Command {
  _UpCommand(this.migrationRunner);

  @override
  String get name => 'up';
  @override
  String get description => 'Runs outstanding migrations.';

  final MigrationRunner migrationRunner;

  @override
  Future run() {
    return migrationRunner.up();
  }
}

class _ResetCommand extends Command {
  _ResetCommand(this.migrationRunner);

  @override
  String get name => 'reset';
  @override
  String get description => 'Resets the database.';

  final MigrationRunner migrationRunner;

  @override
  Future run() {
    return migrationRunner.reset();
  }
}

class _RefreshCommand extends Command {
  _RefreshCommand(this.migrationRunner);

  @override
  String get name => 'refresh';
  @override
  String get description =>
      'Resets the database, and then re-runs all migrations.';

  final MigrationRunner migrationRunner;

  @override
  Future run() {
    return migrationRunner.reset().then((_) => migrationRunner.up());
  }
}

class _RollbackCommand extends Command {
  _RollbackCommand(this.migrationRunner);

  @override
  String get name => 'rollback';
  @override
  String get description => 'Undoes the last batch of migrations.';

  final MigrationRunner migrationRunner;

  @override
  Future run() {
    return migrationRunner.rollback();
  }
}
