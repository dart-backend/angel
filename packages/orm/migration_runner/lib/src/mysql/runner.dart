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

  Future _init() async {
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
          //print(result);
          _log.info('Check and create "migrations" table');
        })
        .catchError((e) {
          //print(e);
          _log.severe('Failed to create "migrations" table.');
          throw e;
        });

    var result = await connection.execute('SELECT path from migrations;');
    var renames = legacyPathRenames(
      result.rows.map((row) => row.colAt(0) ?? ''),
      migrations.values,
    );
    for (var MapEntry(key: path, value: name) in renames.entries) {
      await connection.execute(
        'UPDATE migrations SET path = :name WHERE path = :path',
        {'name': name, 'path': path},
      );
      _log.info('Renamed "$path" to "$name" in "migrations" table.');
    }
  }

  @override
  Future up() async {
    await _init();
    var result = await connection.execute('SELECT path from migrations;');
    var existing = <String>[];
    for (var item in result.rows) {
      existing.add(item.colAt(0) ?? '');
    }
    var toRun = <String>[];

    migrations.forEach((k, v) {
      if (!existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      var result = await connection.execute(
        'SELECT MAX(batch) from migrations;',
      );
      var curBatch = 0;
      if (result.rows.isNotEmpty) {
        var firstRow = result.rows.first;
        curBatch = int.tryParse(firstRow.colAt(0) ?? "0") ?? 0;
      }
      curBatch++;

      for (var k in toRun) {
        var migration = migrations[k]!;
        var schema = MySqlSchema();
        migration.up(schema);
        _log.info('Added "$k" into "migrations" table.');
        await schema.run(connection).then((_) async {
          var result = await connection
              .execute(
                'INSERT INTO migrations (batch, path) VALUES (:batch, :path)',
                {'batch': curBatch, 'path': k},
              )
              .catchError((e) {
                _log.severe('Failed to insert into "migrations" table.', e);
                throw Exception(e);
              });

          return result.affectedRows.toInt();
        });
      }
    } else {
      _log.warning('Nothing to add into "migrations" table.');
    }
  }

  @override
  Future rollback() async {
    await _init();

    var result = await connection.execute('SELECT MAX(batch) from migrations;');
    var curBatch = 0;
    if (result.rows.isNotEmpty) {
      var firstRow = result.rows.first;
      curBatch = int.tryParse(firstRow.colAt(0) ?? "0") ?? 0;
    }
    result = await connection.execute(
      'SELECT path from migrations WHERE batch = $curBatch;',
    );
    var existing = <String>[];
    for (var item in result.rows) {
      existing.add(item.colAt(0) ?? '');
    }
    var toRun = <String>[];

    migrations.forEach((k, v) {
      if (existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      for (var k in toRun.reversed) {
        var migration = migrations[k]!;
        var schema = MySqlSchema();
        migration.down(schema);
        _log.info('Removed "$k" from "migrations" table.');
        await schema.run(connection).then((_) {
          return connection.execute(
            'DELETE FROM migrations WHERE path = :path',
            {'path': k},
          );
        });
      }
    } else {
      _log.warning('Nothing to remove from "migrations" table.');
    }
  }

  @override
  Future reset() async {
    await _init();
    var result = await connection.execute(
      'SELECT path from migrations ORDER BY batch DESC, id DESC;',
    );
    var existing = <String>[];
    for (var item in result.rows) {
      existing.add(item.colAt(0) ?? '');
    }

    var toRun = existing.where(migrations.containsKey).toList();

    if (toRun.isNotEmpty) {
      // The newest first, as it may depend on those before.
      for (var k in toRun) {
        var migration = migrations[k]!;
        var schema = MySqlSchema();
        migration.down(schema);
        _log.info('Removed "$k" from "migrations" table.');
        await schema.run(connection).then((_) {
          return connection.execute(
            'DELETE FROM migrations WHERE path = :path',
            {'path': k},
          );
        });
      }
    } else {
      _log.warning('Nothing to remove from "migrations" table.');
    }
  }

  @override
  Future close() {
    return connection.close();
  }
}
