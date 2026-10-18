import 'dart:async';
import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';

import '../runner.dart';
import '../util.dart';
import 'schema.dart';

/// A MySQL database migration runner.
class MySqlMigrationRunner implements MigrationRunner {
  final _log = Logger('MysqlMigrationRunner');

  final Map<String, Migration> migrations = {};
  final Queue<Migration> _migrationQueue = Queue();
  final MySQLConnection connection;
  bool _connected = false;

  MySqlMigrationRunner(
    this.connection, {
    Iterable<Migration> migrations = const [],
    bool connected = false,
  }) {
    if (migrations.isNotEmpty) {
      migrations.forEach(addMigration);
    }
    _connected = connected;
  }

  @override
  void addMigration(Migration migration) {
    _migrationQueue.addLast(migration);
  }

  /// Creates the `migrations` table if needed, and returns its paths.
  Future<List<String>> _init() async {
    addQueuedMigrations(_migrationQueue, migrations);

    if (!_connected) {
      _connected = true;
    }

    await connection
        .execute('''
    CREATE TABLE IF NOT EXISTS migrations (
      id integer NOT NULL AUTO_INCREMENT,
      batch integer,
      path varchar(500),
      PRIMARY KEY(id)
    );
    ''')
        .then((result) {
          _log.info('Check and create "migrations" table');
        })
        .catchError((Object e, StackTrace s) {
          _log.severe('Failed to create "migrations" table.', e, s);
          Error.throwWithStackTrace(e, s);
        });

    return applyLegacyPaths(
      await _paths('SELECT path from migrations ORDER BY id;'),
      migrations.values,
      rename: (path, name) => connection.execute(
        'UPDATE migrations SET path = :name WHERE path = :path',
        {'name': name, 'path': path},
      ),
      delete: _delete,
      log: _log,
    );
  }

  Future<List<String>> _paths(String sql) async => migrationPaths([
    for (var row in (await connection.execute(sql)).rows) row.colAt(0),
  ]);

  Future<int> _lastBatch() async {
    var result = await connection.execute('SELECT MAX(batch) from migrations;');
    return batchNumber(result.rows.firstOrNull?.colAt(0));
  }

  Future<void> _delete(String path) => connection.execute(
    'DELETE FROM migrations WHERE path = :path',
    {'path': path},
  );

  @override
  Future up() async {
    var existing = await _init();
    var toRun = <String>[];

    migrations.forEach((k, v) {
      if (!existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      var batch = await _lastBatch() + 1;

      for (var k in toRun) {
        var migration = migrations[k]!;
        var schema = MySqlSchema();
        migration.up(schema);
        _log.info('Added "$k" into "migrations" table.');
        // Throws if it fails, as the migrations after it may depend on it.
        await schema.run(connection);
        await connection
            .execute(
              'INSERT INTO migrations (batch, path) VALUES (:batch, :path)',
              {'batch': batch, 'path': k},
            )
            .catchError((Object e, StackTrace s) {
              _log.severe('Failed to insert into "migrations" table.', e, s);
              Error.throwWithStackTrace(e, s);
            });
      }
    } else {
      _log.warning('Nothing to add into "migrations" table.');
    }
  }

  @override
  Future rollback() async {
    await _init();

    // The newest first, as it may depend on those before.
    var toRun = (await _paths(
      'SELECT path from migrations WHERE batch = ${await _lastBatch()} '
      'ORDER BY id DESC;',
    )).where(migrations.containsKey).toList();
    await _down(toRun);
  }

  @override
  Future reset() async {
    await _init();
    // The newest first, as it may depend on those before.
    var toRun = (await _paths(
      'SELECT path from migrations ORDER BY batch DESC, id DESC;',
    )).where(migrations.containsKey).toList();
    await _down(toRun);
  }

  /// Runs the `down` of the migrations [toRun], in order, and removes them
  /// from the `migrations` table.
  Future<void> _down(List<String> toRun) async {
    if (toRun.isEmpty) {
      _log.warning('Nothing to remove from "migrations" table.');
      return;
    }
    for (var k in toRun) {
      var schema = MySqlSchema();
      migrations[k]!.down(schema);
      _log.info('Removed "$k" from "migrations" table.');
      await schema.run(connection);
      await _delete(k);
    }
  }

  @override
  Future close() {
    return connection.close();
  }
}
