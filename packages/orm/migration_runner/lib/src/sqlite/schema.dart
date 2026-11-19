import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/common.dart';

import '../sql.dart';
import 'table.dart';

/// A SQLite database schema generator.
class SqliteSchema extends Schema {
  final _log = Logger('SqliteSchema');

  final StringBuffer _buf = StringBuffer();

  /// Runs the SQL of the schema on [database], and throws if it fails. It is
  /// not run in a transaction of its own: [SqliteMigrationRunner] runs it in
  /// one with the record of its migration.
  void run(CommonDatabase database) {
    var sql = compile();
    if (sql.trim().isEmpty) return;
    try {
      database.execute(sql);
    } catch (e) {
      _log.severe('Failed to run query: [ $sql ]', e);
      rethrow;
    }
  }

  String compile() => _buf.toString();

  /// Drops the table [tableName]. SQLite has no `CASCADE`, so [cascade] is
  /// ignored: with `PRAGMA foreign_keys = ON`, the rows that refer to the
  /// table must be deleted first.
  @override
  void drop(String tableName, {bool cascade = false}) {
    _buf.writeln('DROP TABLE ${quotePostgresTableName(tableName)};');
  }

  @override
  void alter(String tableName, void Function(MutableTable table) callback) {
    var tbl = SqliteAlterTable(tableName);
    callback(tbl);
    tbl.compile(_buf, 0);
  }

  void _create(
    String tableName,
    void Function(Table table) callback,
    bool ifNotExists,
  ) {
    var op = ifNotExists ? ' IF NOT EXISTS' : '';
    var tbl = SqliteTable();
    callback(tbl);
    _buf.writeln('CREATE TABLE$op ${quotePostgresTableName(tableName)} (');
    tbl.compile(_buf, 1);
    _buf.writeln();
    _buf.writeln(');');
    tbl.compileIndexes(_buf, tableName, 0);
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
    var tbl = SqliteIndexes(tableName);
    callback(tbl);
    tbl.compile(_buf);
  }
}
