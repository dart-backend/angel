import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';

import 'runner.dart';

/// Runs the Angel Migration CLI, and then closes [migrationRunner], whether
/// the command succeeds or throws, as when a migration fails.
///
/// The error of a command that throws is thrown, rather than one of closing
/// the runner, as on a connection that was lost, which is logged.
Future runMigrations(MigrationRunner migrationRunner, List<String> args) async {
  var cmd = CommandRunner('migration_runner', 'Executes Angel3 migrations.')
    ..addCommand(_UpCommand(migrationRunner))
    ..addCommand(_RefreshCommand(migrationRunner))
    ..addCommand(_ResetCommand(migrationRunner))
    ..addCommand(_RollbackCommand(migrationRunner));
  try {
    await cmd.run(args);
  } catch (e) {
    try {
      await migrationRunner.close();
    } catch (closeError, closeStack) {
      _log.warning('Failed to close the runner.', closeError, closeStack);
    }
    rethrow;
  }
  await migrationRunner.close();
}

final _log = Logger('runMigrations');

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
  String get description => 'Undo the last batch of migrations.';

  final MigrationRunner migrationRunner;

  @override
  Future run() {
    return migrationRunner.rollback();
  }
}
