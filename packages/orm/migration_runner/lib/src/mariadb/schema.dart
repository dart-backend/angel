import 'dart:async';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:mysql1/mysql1.dart';

import '../change_column.dart';
import 'table.dart';

/// A MariaDB database schema generator
class MariaDbSchema extends Schema {
  final _log = Logger('MariaDbSchema');

  final int _indent;
  final StringBuffer _buf;

  late final _alters = SchemaAlters(_log);

  MariaDbSchema._(this._buf, this._indent);

  factory MariaDbSchema() => MariaDbSchema._(StringBuffer(), 0);

  /// Runs the SQL of the schema in a transaction, and throws if it fails.
  ///
  /// The statements before an alter table that changes a column's type are
  /// run before the column's constraints are read, as they may create the
  /// table or rename the column.
  Future<int> run(MySqlConnection connection) async {
    // Throws for SQL that cannot be compiled, such as a precision too large,
    // before any of it is run.
    compile();

    var affectedRows = 0;
    await connection.transaction((TransactionContext ctx) async {
      await _alters.run(
        _buf,
        execute: (sql) async {
          Results? result = await ctx.query(sql).catchError((e) {
            _log.severe('Failed to run query: [ $sql ]', e);
            throw e;
          });
          affectedRows += result.affectedRows ?? 0;
        },
        // `mysql1` may give text as a `Blob`.
        query: (sql) async => [
          for (var row in await ctx.query(sql))
            [for (var value in row) value?.toString()],
        ],
      );
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
    var tbl = MariaDbAlterTable(tableName);
    callback(tbl);
    _alters.add(_buf, tbl, _indent);
  }

  void _create(
    String tableName,
    void Function(Table table) callback,
    bool ifNotExists,
  ) {
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
    String tableName,
    void Function(Table table) callback,
  ) => _create(tableName, callback, true);

  @override
  void indexes(String tableName, void Function(MutableIndexes index) callback) {
    var tbl = MariaDbIndexes(tableName);
    callback(tbl);

    tbl.compile(_buf);
  }
}
