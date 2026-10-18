import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';

import 'change_column.dart';
import 'sql.dart';

/// A table that compiles its columns for a `CREATE TABLE`.
abstract class CompiledTable extends Table {
  void compile(StringBuffer buf, int indent);
}

/// Indexes that compile their statements.
abstract interface class CompiledIndexes implements MutableIndexes {
  void compile(StringBuffer buf);
}

/// An alter table of MySQL or MariaDB, which compile its columns with
/// [compileColumn], and whose changes of column types are compiled with the
/// constraints read from the database.
abstract class ModifyingAlterTable extends Table implements MutableTable {
  final String tableName;

  /// Compiles a column, with its type, constraints and references.
  final String Function(MigrationColumn column) compileColumn;

  /// Whether indexes are added with `IF NOT EXISTS` and dropped with
  /// `IF EXISTS`, which MariaDB has and MySQL has not.
  final bool ifExists;

  /// The changes of column types, whose constraints not given are read from
  /// the database when the schema is run.
  final List<ColumnModification> modifications = [];

  final Map<String, MigrationColumn> _columns = {};
  final Queue<Object> _stack = Queue<Object>();

  ModifyingAlterTable(
    this.tableName,
    this.compileColumn, {
    required this.ifExists,
  });

  /// Compiles the clauses of the table, which may be compiled again.
  void compile(StringBuffer buf, int indent) {
    // The changes and the columns added are clauses of one statement.
    var clauses = [
      for (var entry in _stack)
        entry is ColumnModification ? entry.compile(compileColumn) : entry,
      for (var MapEntry(key: name, value: column) in _columns.entries)
        'ADD COLUMN $name ${compileColumn(column)}',
    ];
    buf.write(clauses.map((clause) => '${'  ' * indent}$clause').join(',\n'));
  }

  @override
  MigrationColumn declareColumn(String name, Column column) {
    if (_columns.containsKey(name)) {
      throw StateError('Cannot redeclare column $name.');
    }
    var col = MigrationColumn.from(column);
    // Checks the precision and scale against the database's limits when the
    // column is declared, before any of the schema is run.
    compileColumn(col);
    _columns[name] = col;
    return col;
  }

  @override
  void dropNotNull(String name) {
    _stack.add('ALTER COLUMN $name DROP NOT NULL');
  }

  @override
  void setNotNull(String name) {
    _stack.add('ALTER COLUMN $name SET NOT NULL');
  }

  @override
  void changeColumnType(
    String name,
    ColumnType type, {
    int length = Column.defaultLength,
    int? precision,
    int? scale,
    bool? isNullable,
    Object? defaultValue,
    bool? autoIncrement,
    String? using,
  }) {
    // MODIFY converts the values itself, so `using` is not needed.
    var modification = ColumnModification(
      name,
      type,
      length: length,
      precision: precision,
      scale: scale,
      isNullable: isNullable,
      defaultValue: defaultValue,
      autoIncrement: autoIncrement,
    );
    // Checks the precision and scale against the database's limits when the
    // change is declared, before any of the schema is run.
    modification.compile(compileColumn);
    modifications.add(modification);
    _stack.add(modification);
  }

  @override
  void renameColumn(String name, String newName) {
    _stack.add('RENAME COLUMN $name TO $newName');
  }

  @override
  void dropColumn(String name) {
    _stack.add('DROP COLUMN $name');
  }

  @override
  void rename(String newName) {
    _stack.add('RENAME TO $newName');
  }

  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    var ifNotExists = ifExists ? 'IF NOT EXISTS ' : '';
    var indexType = switch (type) {
      IndexType.primaryKey => 'PRIMARY KEY',
      IndexType.unique => 'UNIQUE INDEX $ifNotExists`$name`',
      IndexType.standardIndex || IndexType.none => 'INDEX $ifNotExists`$name`',
    };
    _stack.add('ADD $indexType (${columns.join(',')})');
  }

  @override
  void dropIndex(String name) {
    _stack.add('DROP INDEX ${ifExists ? 'IF EXISTS ' : ''}`$name`');
  }

  @override
  void dropPrimaryIndex() {
    _stack.add('DROP PRIMARY KEY');
  }
}

/// A MySQL or MariaDB schema, whose tables, alter tables and indexes are
/// those of [newTable], [newAlterTable] and [newIndexes].
///
/// Its statements are run by [runWith], with the client of the database.
abstract class MySqlFamilySchema extends Schema {
  final StringBuffer _buf = StringBuffer();
  final _alters = SchemaAlters();

  CompiledTable newTable();

  ModifyingAlterTable newAlterTable(String tableName);

  CompiledIndexes newIndexes(String tableName);

  /// The SQL of the schema. A change of a column's type keeps the constraints
  /// not given only when it is run, which reads them from the database.
  String compile() => _alters.compile(_buf);

  /// Runs the SQL of the schema with [execute], and reads the constraints of
  /// the columns whose types are changed with [query], as
  /// [SchemaAlters.run].
  Future<void> runWith({
    required Future<void> Function(String sql) execute,
    required Future<List<List<String?>>> Function(String sql) query,
  }) => _alters.run(_buf, execute: execute, query: query);

  @override
  void drop(String tableName, {bool cascade = false}) {
    var c = cascade == true ? ' CASCADE' : '';
    _buf.writeln('DROP TABLE $tableName$c;');
  }

  @override
  void alter(String tableName, void Function(MutableTable table) callback) {
    var tbl = newAlterTable(tableName);
    callback(tbl);
    _alters.add(_buf, tbl, 0);
  }

  void _create(
    String tableName,
    void Function(Table table) callback,
    bool ifNotExists,
  ) {
    var op = ifNotExists ? ' IF NOT EXISTS' : '';
    var tbl = newTable();
    callback(tbl);
    _buf.writeln('CREATE TABLE$op $tableName (');
    tbl.compile(_buf, 1);
    _buf.writeln();
    _buf.writeln(');');
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
    var tbl = newIndexes(tableName);
    callback(tbl);
    tbl.compile(_buf);
  }
}

/// The alter tables of a MySQL or MariaDB schema, each with the text compiled
/// before it and its indent, which are compiled with the constraints that
/// [run] reads from the database just before them.
class SchemaAlters {
  final List<(String, ModifyingAlterTable, int)> _alters = [];

  /// Adds [table], after the text of [buf], which is cleared.
  void add(StringBuffer buf, ModifyingAlterTable table, int indent) {
    _alters.add((buf.toString(), table, indent));
    buf.clear();
  }

  /// The SQL of the schema, whose text after the last alter table is [rest].
  /// A change of a column's type keeps the constraints not given only when
  /// [run] has read them from the database.
  String compile(StringBuffer rest) {
    var buf = StringBuffer();
    for (var (text, table, indent) in _alters) {
      buf.write(text);
      _compileAlter(buf, table, indent);
    }
    buf.write(rest);
    return buf.toString();
  }

  /// Runs the SQL of the schema, whose text after the last alter table is
  /// [rest], with [execute], and reads the constraints with [query], which
  /// gives the rows of a query as text.
  ///
  /// The statements before an alter table that changes a column's type are
  /// run before the column's constraints are read, as they may create the
  /// table or rename the column.
  Future<void> run(
    StringBuffer rest, {
    required Future<void> Function(String sql) execute,
    required Future<List<List<String?>>> Function(String sql) query,
  }) async {
    Future<void> executeText(String sql) async {
      if (sql.trim().isNotEmpty) await execute(sql);
    }

    var buf = StringBuffer();
    for (var (text, table, indent) in _alters) {
      buf.write(text);
      if (table.modifications.any((m) => m.keepsExisting)) {
        await executeText(buf.toString());
        buf.clear();
        await _readExisting(table, query);
      }
      _compileAlter(buf, table, indent);
    }
    buf.write(rest);
    await executeText(buf.toString());
  }

  void _compileAlter(StringBuffer buf, ModifyingAlterTable table, int indent) {
    buf.write('  ' * indent);
    buf.writeln('ALTER TABLE ${table.tableName}');
    table.compile(buf, indent + 1);
    buf.writeln(';');
  }

  /// Reads the constraints of the columns of [table] whose types are changed,
  /// which a `MODIFY` keeps only if it gives them again, from the database,
  /// in one query.
  Future<void> _readExisting(
    ModifyingAlterTable table,
    Future<List<List<String?>>> Function(String sql) query,
  ) async {
    var modifications = [
      for (var m in table.modifications)
        if (m.keepsExisting) m,
    ];
    var rows = await query(
      existingConstraintsQuery(
        table.tableName,
        modifications.map((m) => m.name).toSet(),
      ),
    );
    // The names of columns are not case sensitive.
    var byName = {for (var row in rows) row[0]?.toLowerCase(): row};
    for (var modification in modifications) {
      var row = byName[unquoteIdentifier(modification.name).toLowerCase()];
      // Without them, the MODIFY would drop the constraints.
      if (row == null) {
        throw StateError(
          'Cannot change the type of column ${modification.name} of table '
          '${table.tableName}: it is not found in information_schema, so its '
          'constraints not given to changeColumnType cannot be kept',
        );
      }
      modification.existing = ExistingConstraints.parse(
        isNullable: row[1] ?? 'YES',
        columnDefault: row[2],
        extra: row[3] ?? '',
        dataType: row[4] ?? '',
        version: row[5] ?? '',
      );
    }
  }
}
