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

  /// Runs the SQL of the schema with [session], and throws if it fails: in a
  /// transaction of its own, if [session] is a [Connection] or another that
  /// runs them, or in that of a transaction it is of.
  Future<int> run(Session session) async {
    if (session is SessionExecutor) {
      return (session as SessionExecutor).runTx(_execute);
    }
    return _execute(session);
  }

  Future<int> _execute(Session session) async {
    var sql = compile();
    if (sql.trim().isEmpty) return 0;
    // The simple protocol, as the extended one takes only one statement.
    var result = await session
        .execute(sql, queryMode: QueryMode.simple)
        .catchError((Object e) {
          _log.severe('Failed to run query: [ $sql ]', e);
          throw Exception(e);
        });
    return result.affectedRows;
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
    _writeln('DROP TABLE ${quotePostgresTableName(tableName)}$c;');
  }

  @override
  void alter(String tableName, void Function(MutableTable table) callback) {
    var tbl = PostgresAlterTable(tableName);
    callback(tbl);
    tbl.compile(_buf, _indent);
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
    _writeln('CREATE TABLE$op ${quotePostgresTableName(tableName)} (');
    tbl.compile(_buf, _indent + 1);
    _buf.writeln();
    _writeln(');');
    tbl.compileIndexes(_buf, tableName, _indent);
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
