import 'dart:async';
import 'dart:collection';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';
import '../runner.dart';
import '../util.dart';
import 'schema.dart';

class MySqlMigrationRunner implements MigrationRunner {
  final _log = Logger('MysqlMigrationRunner');

  final Map<String, Migration> migrations = {};
  final Queue<Migration> _migrationQueue = Queue();
  final MySQLConnection connection;
  bool _connected = false;

  MySqlMigrationRunner(this.connection,
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
      _connected = true;
    }

    await connection.execute('''
    CREATE TABLE IF NOT EXISTS migrations (
      id serial,
      batch integer,
      path varchar(255),
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
    var result = await connection.execute('SELECT path from migrations;');
    var existing = <String>[];
    if (result.rows.isNotEmpty) {
      existing = result.rows.first.assoc().values.cast<String>().toList();
    }
    var toRun = <String>[];

    migrations.forEach((k, v) {
      if (!existing.contains(k)) toRun.add(k);
    });

    if (toRun.isNotEmpty) {
      var result =
          await connection.execute('SELECT MAX(batch) from migrations;');
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
                  "INSERT INTO migrations (batch, path) VALUES ($curBatch, '$k')")
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
    result = await connection
        .execute('SELECT path from migrations WHERE batch = $curBatch;');
    var existing = <String>[];
    if (result.rows.isNotEmpty) {
      existing = result.rows.first.assoc().values.cast<String>().toList();
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
    var result = await connection
        .execute('SELECT path from migrations ORDER BY batch DESC;');
    var existing = <String>[];
    if (result.rows.isNotEmpty) {
      var firstRow = result.rows.first;
      existing = firstRow.assoc().values.cast<String>().toList();
    }
    var toRun = existing.where(migrations.containsKey).toList();

    if (toRun.isNotEmpty) {
      for (var k in toRun.reversed) {
        var migration = migrations[k]!;
        var schema = MySqlSchema();
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
