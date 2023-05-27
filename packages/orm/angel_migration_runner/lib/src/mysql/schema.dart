import 'dart:async';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';

import 'table.dart';

class MySqlSchema extends Schema {
  final _log = Logger('MysqlSchema');

  final int _indent;
  final StringBuffer _buf;

  MySqlSchema._(this._buf, this._indent);

  factory MySqlSchema() => MySqlSchema._(StringBuffer(), 0);

  Future<int> run(MySQLConnection connection) async {
    //return connection.execute(compile());
    int affectedRows = 0;
    await connection.transactional((ctx) async {
      var sql = compile();
      var result = await ctx.execute(sql).catchError((e) {
        _log.severe('Failed to run query: [ $sql ]', e);
        throw Exception(e);
      });
      affectedRows = result.affectedRows.toInt();
    }).catchError((e) {
      _log.severe('Failed to run query in a transaction', e);
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
    var tbl = MysqlAlterTable(tableName);
    callback(tbl);
    _writeln('ALTER TABLE $tableName');
    tbl.compile(_buf, _indent + 1);
    _buf.write(';');
  }

  void _create(
      String tableName, void Function(Table table) callback, bool ifNotExists) {
    var op = ifNotExists ? ' IF NOT EXISTS' : '';
    var tbl = MysqlTable();
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
