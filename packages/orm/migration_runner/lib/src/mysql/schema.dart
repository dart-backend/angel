import 'dart:async';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql_client/mysql_client.dart';

import '../change_column.dart';
import 'table.dart';

/// A MySQL database schema generator
class MySqlSchema extends Schema {
  final _log = Logger('MysqlSchema');

  final int _indent;
  final StringBuffer _buf;

  late final _alters = SchemaAlters(_log);

  MySqlSchema._(this._buf, this._indent);

  factory MySqlSchema() => MySqlSchema._(StringBuffer(), 0);

  /// Runs the SQL of the schema in a transaction, and throws if it fails.
  ///
  /// The statements before an alter table that changes a column's type are
  /// run before the column's constraints are read, as they may create the
  /// table or rename the column.
  Future<int> run(MySQLConnection connection) async {
    // Throws for SQL that cannot be compiled, such as a precision too large,
    // before any of it is run.
    compile();

    var affectedRows = 0;
    await connection
        .transactional((ctx) async {
          await _alters.run(
            _buf,
            execute: (sql) async {
              //print('Query: $sql');
              var result = await ctx.execute(sql).catchError((e) {
                _log.severe('Failed to run query: [ $sql ]', e);
                throw Exception(e);
              });
              affectedRows += result.affectedRows.toInt();
            },
            query: (sql) async {
              var result = await ctx.execute(sql);
              return [
                for (var row in result.rows)
                  [for (var i = 0; i < result.numOfColumns; i++) row.colAt(i)],
              ];
            },
          );
        })
        .catchError((e) {
          _log.severe('Failed to run query in a transaction', e);
          throw e;
        });

    return affectedRows;
  }

  /// The SQL of the schema. A change of a column's type keeps the constraints
  /// not given only when [run] has read them from the database.
  String compile() => _alters.compile(_buf);

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
    _alters.add(_buf, tbl, _indent);
  }

  void _create(
    String tableName,
    void Function(Table table) callback,
    bool ifNotExists,
  ) {
    var op = ifNotExists ? ' IF NOT EXISTS' : '';
    var tbl = MysqlTable();
    callback(tbl);
    _writeln('CREATE TABLE$op $tableName (');
    tbl.compile(_buf, _indent + 1);
    _buf.writeln();
    _writeln(');');

    //_log.fine(_buf);
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
    var tbl = MysqlIndexes(tableName);
    callback(tbl);

    tbl.compile(_buf);
  }
}
