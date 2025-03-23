import 'dart:async';
import 'dart:collection';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';
import '../runner.dart';
import '../util.dart';
import 'schema.dart';

/// A MariaDB database migration runner.
class MariaDbMigrationRunner implements MigrationRunner {
  final _log = Logger('MariaDbMigrationRunner');

  final Map<String, Migration> migrations = {};
  final Queue<Migration> _migrationQueue = Queue();
  final MySqlConnection connection;
  //bool _connected = false;

  MariaDbMigrationRunner(this.connection,
      {Iterable<Migration> migrations = const [], bool connected = true}) {
    if (migrations.isNotEmpty) migrations.forEach(addMigration);
    //_connected = connected;
  }

  @override
  void addMigration(Migration migration) {
    _migrationQueue.addLast(migration);
  }

  Future _init() async {
    while (_migrationQueue.isNotEmpty) {
      var migration = _migrationQueue.removeFirst();
      var path = await absoluteSourcePath(migration.runtimeType);
      migrations.putIfAbsent(path.replaceAll('\\', '\\\\'), () => migration);
    }

    await connection.query('''
    CREATE TABLE IF NOT EXISTS migrations (
      id integer NOT NULL AUTO_INCREMENT,
      batch integer,
      path varchar(500),
      PRIMARY KEY(id)
    );
    ''').then((result) {
      //print(result.affectedRows);
      _log.fine('Check and create "migrations" table');
    }).catchError((e) {
      //print(e);
      _log.severe('Failed to create "migrations" table.', e);
    });
  }

  @override
  Future up() async {
    await _init();
    var result = await connection.query('SELECT path from migrations;');

    var existing = <String>[];
    if (result.isNotEmpty) {
      var pathList = result.expand((x) => x).cast<String>().toList();
      for (var path in pathList) {
        existing.add(path.replaceAll("\\", "\\\\"));
      }
    }

    var toRun = <String>[];
    migrations.forEach((k, v) {
      if (!existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      var result = await connection.query('SELECT MAX(batch) from migrations;');
      var curBatch = 0;
      if (result.isNotEmpty) {
        var firstRow = result.toList();
        var firstBatch = firstRow[0][0] ?? 0;
        if (firstBatch is! int) {
          int.tryParse(firstBatch) as int;
        }
        curBatch = firstBatch;
      }
      var batch = curBatch + 1;

      for (var k in toRun) {
        var migration = migrations[k]!;
        var schema = MariaDbSchema();
        migration.up(schema);
        _log.info('Added "$k" into "migrations" table.');
        try {
          await schema.run(connection).then((_) async {
            var result = await connection.query(
                "INSERT INTO migrations (batch, path) VALUES ($batch, '$k')");

            return result.affectedRows;
          });
        } catch (e) {
          _log.severe('Failed to insert into "migrations" table.', e);
        }
      }
    } else {
      _log.warning('Nothing to add into "migrations" table.');
    }
  }

  @override
  Future rollback() async {
    await _init();

    var result = await connection.query('SELECT MAX(batch) from migrations;');

    var curBatch = 0;
    if (result.isNotEmpty) {
      var firstRow = result.toList();
      var firstBatch = firstRow[0][0];
      if (firstBatch is! int) {
        int.tryParse(firstBatch) as int;
      }
      curBatch = firstBatch;
    }

    result = await connection
        .query('SELECT path from migrations WHERE batch = $curBatch;');
    var existing = <String>[];
    if (result.isNotEmpty) {
      var pathList = result.expand((x) => x).cast<String>().toList();
      for (var path in pathList) {
        existing.add(path.replaceAll("\\", "\\\\"));
      }
    }

    var toRun = <String>[];

    migrations.forEach((k, v) {
      if (existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      for (var k in toRun.reversed) {
        var migration = migrations[k]!;
        var schema = MariaDbSchema();
        migration.down(schema);
        _log.info('Removed "$k" from "migrations" table.');
        await schema.run(connection).then((_) {
          return connection
              .query('DELETE FROM migrations WHERE path = \'$k\';');
        });
      }
    } else {
      _log.warning('Nothing to remove from "migrations" table.');
    }
  }

  @override
  Future reset() async {
    await _init();
    var r = await connection
        .query('SELECT path from migrations ORDER BY batch DESC;');
    var existing = <String>[];
    if (r.isNotEmpty) {
      var pathList = r.expand((x) => x).cast<String>().toList();
      for (var path in pathList) {
        existing.add(path.replaceAll("\\", "\\\\"));
      }
    }

    var toRun = existing.where(migrations.containsKey).toList();

    if (toRun.isNotEmpty) {
      for (var k in toRun.reversed) {
        var migration = migrations[k]!;
        var schema = MariaDbSchema();
        migration.down(schema);
        _log.info('Removed "$k" from "migrations" table.');
        await schema.run(connection).then((_) {
          return connection
              .query('DELETE FROM migrations WHERE path = \'$k\';');
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
