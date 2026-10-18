import 'dart:async';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import '../sql.dart';
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
      // The simple protocol, as the extended one takes only one statement.
      var result = await ctx
          .execute(sql, queryMode: QueryMode.simple)
          .catchError((e) {
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
    _writeln('DROP TABLE ${quotePostgresIdentifier(tableName)}$c;');
  }

  @override
  void alter(String tableName, void Function(MutableTable table) callback) {
    var tbl = PostgresAlterTable(tableName);
    callback(tbl);
    _writeln('ALTER TABLE ${quotePostgresIdentifier(tableName)}');
    tbl.compile(_buf, _indent + 1);
    _buf.writeln(';');
    tbl.compileSequences(_buf);
  }

  void _create(
    String tableName,
    void Function(Table table) callback,
    bool ifNotExists,
  ) {
    var op = ifNotExists ? ' IF NOT EXISTS' : '';
    var tbl = PostgresTable();
    callback(tbl);
    _writeln('CREATE TABLE$op ${quotePostgresIdentifier(tableName)} (');
    tbl.compile(_buf, _indent + 1);
    _buf.writeln();
    _writeln(');');
  }

  @override
  void create(String tableName, void Function(Table table) callback) =>
      _create(tableName, callback, false);

  @override
  void createIfNotExists(
    String tableName,
    void Function(Table table) callback,
  ) => _create(tableName, callback, true);

  @override
  void indexes(String tableName, void Function(MutableIndexes table) callback) {
    var tbl = PostgresIndexes(tableName);
    callback(tbl);

    tbl.compile(_buf);
  }
}
