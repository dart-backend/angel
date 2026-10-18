import 'dart:async';
import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';

import 'runner.dart';
import 'util.dart';

/// A migration runner of a SQL database, which records the migrations run in
/// its `migrations` table, by their [Migration.name] and the batch of the
/// [up] that ran them.
///
/// A database gives how its table is created and queried, its schema [S], and
/// how one is run and recorded, or undone and removed.
abstract class SqlMigrationRunner<S extends Schema> implements MigrationRunner {
  final Logger log;

  /// The migrations added, by their names, once the runner has started.
  final Map<String, Migration> migrations = {};

  final Queue<Migration> _queue = Queue();

  SqlMigrationRunner(this.log, Iterable<Migration> migrations) {
    migrations.forEach(addMigration);
  }

  /// Creates the `migrations` table, with its `id`, `batch` and `path`, if
  /// it does not exist.
  Future<void> createMigrationsTable();

  /// The values of the first column of the rows of [sql].
  Future<List<Object?>> queryColumn(String sql);

  /// Sets [path] of the `migrations` table to [name].
  Future<void> renamePath(String path, String name);

  /// Removes [path] from the `migrations` table.
  Future<void> deletePath(String path);

  /// A new schema of the database.
  S newSchema();

  /// The SQL of [schema].
  String compileSchema(S schema);

  /// Runs [schema], and records [name] in the `migrations` table in [batch],
  /// or removes it without one: in one transaction, if the database changes
  /// its tables in one.
  Future<void> runRecorded(S schema, String name, {int? batch});

  /// Runs the `up` of [migration], and records it as [name] in [batch].
  Future<void> runUp(String name, Migration migration, int batch) {
    var schema = newSchema();
    migration.up(schema);
    return runRecorded(schema, name, batch: batch);
  }

  /// Runs the `down` of [migration], and removes [name].
  Future<void> runDown(String name, Migration migration) {
    var schema = newSchema();
    migration.down(schema);
    return runRecorded(schema, name);
  }

  /// The SQL of the `up` of [migration], by which two migrations of a class
  /// are told to be the same, or not.
  String compileUp(Migration migration) {
    var schema = newSchema();
    migration.up(schema);
    return compileSchema(schema);
  }

  @override
  void addMigration(Migration migration) {
    _queue.addLast(migration);
  }

  /// Creates the `migrations` table if needed, and returns its paths.
  Future<List<String>> _init() async {
    addQueuedMigrations(
      _queue,
      migrations,
      isDuplicate: (a, b) => compileUp(a) == compileUp(b),
      onDuplicate: (m) => log.warning(
        'Skipped a migration "${m.name}" added again, which makes the same '
        'changes as the one added before.',
      ),
    );
    await createMigrationsTable().catchError((Object e, StackTrace s) {
      log.severe('Failed to create "migrations" table.', e, s);
      Error.throwWithStackTrace(e, s);
    });
    return applyLegacyPaths(
      await _paths('SELECT path FROM migrations ORDER BY id'),
      migrations.values,
      rename: renamePath,
      delete: deletePath,
      log: log,
    );
  }

  Future<List<String>> _paths(String sql) async =>
      migrationPaths(await queryColumn(sql));

  Future<int> _lastBatch() async => batchNumber(
    (await queryColumn('SELECT MAX(batch) FROM migrations')).firstOrNull,
  );

  @override
  Future up() async {
    var existing = (await _init()).toSet();
    var toRun = migrations.keys.where((k) => !existing.contains(k)).toList();
    if (toRun.isEmpty) {
      log.warning('Nothing to add into "migrations" table.');
      return;
    }
    var batch = await _lastBatch() + 1;
    for (var k in toRun) {
      try {
        await runUp(k, migrations[k]!, batch);
      } catch (e, s) {
        // The migrations after it may depend on it, so none is run.
        log.severe('Failed to run migration "$k".', e, s);
        rethrow;
      }
      log.info('Added "$k" into "migrations" table.');
    }
  }

  @override
  Future rollback() async {
    await _init();
    var batch = await _lastBatch();
    await _down(
      await _paths(
        'SELECT path FROM migrations WHERE batch = $batch ORDER BY id DESC',
      ),
    );
  }

  @override
  Future reset() async {
    await _init();
    await _down(
      await _paths('SELECT path FROM migrations ORDER BY batch DESC, id DESC'),
    );
  }

  /// Undoes the migrations of [paths], newest first, as one may depend on
  /// those before; each once, if it is recorded more than once.
  Future<void> _down(List<String> paths) async {
    var toRun = paths.where(migrations.containsKey).toSet();
    if (toRun.isEmpty) {
      log.warning('Nothing to remove from "migrations" table.');
      return;
    }
    for (var k in toRun) {
      await runDown(k, migrations[k]!);
      log.info('Removed "$k" from "migrations" table.');
    }
  }
}
