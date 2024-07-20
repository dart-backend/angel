import 'dart:async';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:postgres/postgres.dart';
import 'package:logging/logging.dart';
import 'table.dart';

/// A PostgreSQL database schema generator
class PostgresSchema extends Schema {
  final _log = Logger('PostgresSchema');

  final int _indent;
  final StringBuffer _buf;

  PostgresSchema._(this._buf, this._indent);

  factory PostgresSchema() => PostgresSchema._(StringBuffer(), 0);

  Future<int> run(Connection connection) async {
    //return connection.execute(compile());
    var result = await connection.runTx((ctx) async {
      var sql = compile();
      var result = await ctx.execute(sql).catchError((e) {
        _log.severe('Failed to run query: [ $sql ]', e);
        throw Exception(e);
      });
      return result.affectedRows;
    });

    return result;
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
    _writeln('DROP TABLE "$tableName"$c;');
  }

  @override
  void alter(String tableName, void Function(MutableTable table) callback) {
    var tbl = PostgresAlterTable(tableName);
    callback(tbl);
    _writeln('ALTER TABLE "$tableName"');
    tbl.compile(_buf, _indent + 1);
    _buf.write(';');
  }

  void _create(
      String tableName, void Function(Table table) callback, bool ifNotExists) {
    var op = ifNotExists ? ' IF NOT EXISTS' : '';
    var tbl = PostgresTable();
    callback(tbl);
    _writeln('CREATE TABLE$op "$tableName" (');
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
