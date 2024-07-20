import 'dart:async';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';

import 'table.dart';

/// A MariaDB database schema generator
class MariaDbSchema extends Schema {
  final _log = Logger('MariaDbSchema');

  final int _indent;
  final StringBuffer _buf;

  MariaDbSchema._(this._buf, this._indent);

  factory MariaDbSchema() => MariaDbSchema._(StringBuffer(), 0);

  Future<int> run(MySqlConnection connection) async {
    int affectedRows = 0;
    await connection.transaction((ctx) async {
      var sql = compile();
      Results? result = await ctx.query(sql).catchError((e) {
        _log.severe('Failed to run query: [ $sql ]', e);
        throw e;
      });
      affectedRows = result.affectedRows ?? 0;
    });

    return affectedRows;
  }

  String compile() => _buf.toString();

  void _writeln(String str) {
    for (var i = 0; i < _indent; i++) {
      _buf.write('  ');
    }

    _buf.writeln(str);
  }

  @override
  void drop(String tableName, {bool cascade = false}) {
    var c = cascade == true ? ' CASCADE' : '';
    _writeln('DROP TABLE $tableName$c;');
  }

  @override
  void alter(String tableName, void Function(MutableTable table) callback) {
    var tbl = MariaDbAlterTable(tableName);
    callback(tbl);
    _writeln('ALTER TABLE $tableName');
    tbl.compile(_buf, _indent + 1);
    _buf.write(';');
  }

  void _create(
      String tableName, void Function(Table table) callback, bool ifNotExists) {
    var op = ifNotExists ? ' IF NOT EXISTS' : '';
    var tbl = MariaDbTable();
    callback(tbl);
    _writeln('CREATE TABLE$op $tableName (');
    tbl.compile(_buf, _indent + 1);
    _buf.writeln();
    _writeln(');');
  }

  @override
  void create(String tableName, void Function(Table table) callback) =>
      _create(tableName, callback, false);

  @override
  void createIfNotExists(
          String tableName, void Function(Table table) callback) =>
      _create(tableName, callback, true);
}
