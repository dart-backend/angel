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

  /// The text compiled so far, and the alter tables after it, which are
  /// compiled with the constraints that [run] reads from the database.
  final List<(String, MysqlAlterTable, int)> _alters = [];

  MySqlSchema._(this._buf, this._indent);

  factory MySqlSchema() => MySqlSchema._(StringBuffer(), 0);

  /// The changes of column types, with their tables.
  Iterable<(String, ColumnModification)> get _modifications => _alters.expand(
    (alter) => alter.$2.modifications.map((m) => (alter.$2.tableName, m)),
  );

  Future<int> run(MySQLConnection connection) async {
    //return connection.execute(compile());
    int affectedRows = 0;
    await _readExisting(connection);
    await connection
        .transactional((ctx) async {
          var sql = compile();
          //print('Query: $sql');
          var result = await ctx.execute(sql).catchError((e) {
            _log.severe('Failed to run query: [ $sql ]', e);
            throw Exception(e);
          });
          affectedRows = result.affectedRows.toInt();
        })
        .catchError((e) {
          _log.severe('Failed to run query in a transaction', e);
        });

    return affectedRows;
  }

  /// The SQL of the schema. A change of a column's type keeps the constraints
  /// not given only when [run] has read them from the database first.
  ///
  /// The alter tables are compiled into the text once, so that it can be
  /// compiled again.
  String compile() {
    if (_alters.isNotEmpty) {
      var rest = _buf.toString();
      _buf.clear();
      for (var (text, table, indent) in _alters) {
        _buf.write(text);
        table.compile(_buf, indent);
        _buf.write(';');
      }
      _buf.write(rest);
      _alters.clear();
    }
    return _buf.toString();
  }

  /// Reads the constraints of the columns whose types are changed, which a
  /// `MODIFY` keeps only if it gives them again, from the database.
  Future<void> _readExisting(MySQLConnection connection) async {
    for (var (table, modification) in _modifications) {
      if (!modification.keepsExisting) continue;
      var result = await connection.execute(
        existingConstraintsQuery(table, modification.name),
      );
      if (result.rows.isEmpty) continue;
      var row = result.rows.first;
      modification.existing = ExistingConstraints.parse(
        isNullable: row.colAt(0) ?? 'YES',
        columnDefault: row.colAt(1),
        extra: row.colAt(2) ?? '',
        version: row.colAt(3) ?? '',
      );
    }
  }

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
    _alters.add((_buf.toString(), tbl, _indent + 1));
    _buf.clear();
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
