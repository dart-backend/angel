import 'dart:async';
import 'dart:collection';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:postgres/postgres.dart';
import 'package:logging/logging.dart';
import '../runner.dart';
import '../util.dart';
import 'schema.dart';

class PostgresMigrationRunner implements MigrationRunner {
  final _log = Logger('PostgresMigrationRunner');

  final Map<String, Migration> migrations = {};
  final Connection connection;
  final Queue<Migration> _migrationQueue = Queue();
  bool _connected = false;

  PostgresMigrationRunner(this.connection,
      {Iterable<Migration> migrations = const [], bool connected = false}) {
    if (migrations.isNotEmpty == true) migrations.forEach(addMigration);
    _connected = connected == true;
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

    if (!_connected) {
      //await connection.open();
      //Connection.open(_endpoint!, settings: _settings);
      _connected = true;
    }

    await connection.execute('''
    CREATE TABLE IF NOT EXISTS "migrations" (
      id serial,
      batch integer,
      path varchar,
      PRIMARY KEY(id)
    );
    ''').then((result) {
      _log.info('Check and create "migrations" table');
    }).catchError((e) {
      _log.severe('Failed to create "migrations" table.');
    });
  }

  @override
  Future up() async {
    await _init();
    var r = await connection.execute('SELECT path from migrations;');
    var existing = r.expand((x) => x).cast<String>();
    var toRun = <String>[];

    migrations.forEach((k, v) {
      if (!existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      var r = await connection.execute('SELECT MAX(batch) from migrations;');
      var curBatch = (r[0][0] ?? 0) as int;
      var batch = curBatch + 1;

      for (var k in toRun) {
        var migration = migrations[k]!;
        var schema = PostgresSchema();
        migration.up(schema);
        _log.info('Added "$k" into "migrations" table.');
        await schema.run(connection).then((_) {
          return connection.runTx((ctx) async {
            var result = await ctx.execute(
                "INSERT INTO MIGRATIONS (batch, path) VALUES ($batch, '$k')");

            return result.affectedRows;
          });
        }).catchError((e) {
          _log.severe('Failed to insert into "migrations" table.');
          return -1;
        });
      }
    } else {
      _log.warning('Nothing to add into "migrations" table.');
    }
  }

  @override
  Future rollback() async {
    await _init();

    Result r = await connection.execute('SELECT MAX(batch) from migrations;');
    var curBatch = (r[0][0] ?? 0) as int;
    r = await connection
        .execute('SELECT path from migrations WHERE batch = $curBatch;');
    var existing = r.expand((x) => x).cast<String>();
    var toRun = <String>[];

    migrations.forEach((k, v) {
      if (existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      for (var k in toRun.reversed) {
        var migration = migrations[k]!;
        var schema = PostgresSchema();
        migration.down(schema);
        _log.info('Removed "$k" from "migrations" table.');
        await schema.run(connection).then((_) {
          return connection
              .execute('DELETE FROM migrations WHERE path = \'$k\';');
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
        .execute('SELECT path from migrations ORDER BY batch DESC;');
    var existing = r.expand((x) => x).cast<String>();
    var toRun = existing.where(migrations.containsKey).toList();

    if (toRun.isNotEmpty) {
      for (var k in toRun.reversed) {
        var migration = migrations[k]!;
        var schema = PostgresSchema();
        migration.down(schema);
        _log.info('Removed "$k" from "migrations" table.');
        await schema.run(connection).then((_) {
          return connection
              .execute('DELETE FROM migrations WHERE path = \'$k\';');
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
