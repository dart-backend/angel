import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql1/mysql1.dart' show MySqlException;
import 'package:mysql_dart/exception.dart' show MySQLServerException;

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

/// Compiles the columns of MySQL or MariaDB, whose `numeric` and `decimal`
/// have a scale of at most [maxScale] (and a precision of at most 65).
class MySqlFamilyGenerator {
  final int maxScale;

  const MySqlFamilyGenerator({required this.maxScale});

  String columnType(MigrationColumn column) {
    // A serial type is an integer, with AUTO_INCREMENT.
    var integer = serialIntegers[column.type];
    if (integer != null) return integer.name;

    // Map timestamp time to datetime
    var str = column.type == ColumnType.timeStamp
        ? ColumnType.dateTime.name
        : column.type.name;

    // MySQL and MariaDB have no numeric without a precision, whose default
    // rounds values to whole numbers, so a column without one has
    // Column.defaultPrecision.
    if (column.type.hasPrecision) {
      return '$str'
          '${column.precisionArguments(maxPrecision: 65, maxScale: maxScale)}';
    }
    if (column.type.hasLength) return '$str(${column.length})';
    return str;
  }

  String compileColumn(MigrationColumn column) {
    var buf = StringBuffer(columnType(column));

    if (!column.isNullable) buf.write(' NOT NULL');
    var defaultValue = column.defaultValue;
    if (defaultValue != null) {
      buf.write(
        ' DEFAULT ${compileDefault(defaultValue, escapeBackslashes: true)}',
      );
    }

    if (column.indexType == IndexType.primaryKey) {
      buf.write(' PRIMARY KEY');

      // For int based primary key, apply NOT NULL
      // and AUTO_INCREMENT
      if (column.type == ColumnType.int ||
          serialIntegers.containsKey(column.type)) {
        buf.write(' NOT NULL AUTO_INCREMENT');
      }
    }

    for (var ref in column.externalReferences) {
      buf.write(' ${compileReference(ref)}');
    }

    return buf.toString();
  }

  /// The index of the column [name] in a `CREATE TABLE`, such as
  /// `` INDEX(`a`) ``, or `null` if it has none.
  static String? compileIndex(String name, MigrationColumn column) {
    if (column.indexType == IndexType.standardIndex) {
      return ' INDEX(${quoteMySqlIdentifier(name)})';
    } else if (column.indexType == IndexType.unique) {
      return ' UNIQUE KEY '
          '${quoteMySqlIdentifier('unique_${unquoteIdentifier(name, '`')}')} '
          '(${quoteMySqlIdentifier(name)})';
    }
    return null;
  }

  /// The `REFERENCES` of [ref], whose table, which may be qualified by its
  /// database, and column are quoted, as they may be reserved words.
  static String compileReference(MigrationColumnReference ref) {
    var buf = StringBuffer(
      'REFERENCES ${quoteMySqlTableName(ref.foreignTable)}'
      '(${quoteMySqlIdentifier(ref.foreignKey)})',
    );
    if (ref.behavior != null) buf.write(' ${ref.behavior!}');
    return buf.toString();
  }
}

/// A table of MySQL or MariaDB, whose columns are compiled by [generator].
class MySqlFamilyTable extends CompiledTable {
  final MySqlFamilyGenerator generator;
  final Map<String, MigrationColumn> _columns = {};

  MySqlFamilyTable(this.generator);

  @override
  MigrationColumn declareColumn(String name, Column column) {
    if (_columns.containsKey(name)) {
      throw StateError('Cannot redeclare column "$name".');
    }
    var col = MigrationColumn.from(column);
    _columns[name] = col;
    return col;
  }

  @override
  void compile(StringBuffer buf, int indent) {
    var definitions = <String>[];
    var indexes = <String>[];
    _columns.forEach((name, column) {
      definitions.add(
        '${'  ' * indent}${quoteMySqlIdentifier(name)} '
        '${generator.compileColumn(column)}',
      );
      var index = MySqlFamilyGenerator.compileIndex(name, column);
      if (index != null) indexes.add(index);
    });
    buf.write([...definitions, ...indexes].join(',\n'));
  }
}

/// The indexes of a table of MySQL or MariaDB, which are created with
/// `IF NOT EXISTS` and dropped with `IF EXISTS` if [ifExists], as MariaDB
/// has and MySQL has not.
class MySqlFamilyIndexes implements CompiledIndexes {
  final String tableName;
  final bool ifExists;
  final List<String> _statements = [];

  MySqlFamilyIndexes(this.tableName, {required this.ifExists});

  @override
  void compile(StringBuffer buf) {
    for (var statement in _statements) {
      buf.writeln(statement);
    }
    _statements.clear();
  }

  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    var table = quoteMySqlTableName(tableName);
    var columnList = columns
        .map((c) => compileIndexColumn(c, quoteMySqlPart))
        .join(',');
    var ifNotExists = ifExists ? 'IF NOT EXISTS ' : '';
    var index = quoteMySqlIdentifier(name);
    if (type == IndexType.primaryKey) checkPrimaryKeyColumns(columns);
    _statements.add(switch (type) {
      IndexType.primaryKey =>
        'ALTER TABLE $table ADD PRIMARY KEY ($columnList);',
      IndexType.unique =>
        'CREATE UNIQUE INDEX $ifNotExists$index ON $table ($columnList);',
      IndexType.standardIndex || IndexType.none =>
        'CREATE INDEX $ifNotExists$index ON $table ($columnList);',
    });
  }

  @override
  void dropIndex(String name) {
    _statements.add(
      'DROP INDEX ${ifExists ? 'IF EXISTS ' : ''}${quoteMySqlIdentifier(name)} '
      'ON ${quoteMySqlTableName(tableName)};',
    );
  }

  @override
  void dropPrimaryIndex() {
    _statements.add(
      'DROP INDEX `PRIMARY` ON ${quoteMySqlTableName(tableName)};',
    );
  }
}

/// An alter table of MySQL or MariaDB, which compile its columns with
/// [compileColumn], and whose changes of column types are compiled with the
/// constraints read from the database.
///
/// Its clauses are one `ALTER TABLE` statement, but for a clause of a column
/// renamed or added before it, which starts another, as MySQL and MariaDB
/// know a column of a statement by its name before it. The constraints of the
/// columns changed by a statement are read once those before it have run.
abstract class ModifyingAlterTable extends Table implements MutableTable {
  final String tableName;

  /// Compiles a column, with its type, constraints and references.
  final String Function(MigrationColumn column) compileColumn;

  /// Compiles the index of a column, such as ` INDEX(`a`)`, if it has one.
  final String? Function(String name, MigrationColumn column) compileIndex;

  /// Whether indexes are added with `IF NOT EXISTS` and dropped with
  /// `IF EXISTS`, which MariaDB has and MySQL has not.
  final bool ifExists;

  final Map<String, MigrationColumn> _columns = {};
  final List<_AlterStatement> _statements;

  /// The name of the table after the renames so far.
  String _currentName;

  ModifyingAlterTable(
    this.tableName,
    this.compileColumn, {
    required this.compileIndex,
    required this.ifExists,
  }) : _statements = [_AlterStatement(tableName)],
       _currentName = tableName;

  /// Compiles the `ALTER TABLE` statements of the table, which may be
  /// compiled again.
  void compile(StringBuffer buf, int indent) {
    for (var statement in _statements) {
      _compileStatement(buf, statement, indent);
    }
  }

  void _compileStatement(
    StringBuffer buf,
    _AlterStatement statement,
    int indent,
  ) {
    if (statement.entries.isEmpty) return;
    var clauses = <String>[];
    for (var entry in statement.entries) {
      switch (entry) {
        case ColumnModification():
          clauses.add(entry.compile(compileColumn));
        case _AddedColumn(:var name):
          var column = _columns[name]!;
          clauses.add(
            'ADD COLUMN ${quoteMySqlIdentifier(name)} ${compileColumn(column)}',
          );
          // Its index, as a CREATE TABLE has it.
          var index = compileIndex(name, column);
          if (index != null) clauses.add('ADD$index');
        default:
          clauses.add(entry as String);
      }
    }
    buf.writeln(
      '${'  ' * indent}ALTER TABLE ${quoteMySqlTableName(statement.tableName)}',
    );
    buf.write(
      clauses.map((clause) => '${'  ' * (indent + 1)}$clause').join(',\n'),
    );
    buf.writeln(';');
  }

  /// The name of a column, as MySQL and MariaDB know it: without quotes, and
  /// not case sensitive.
  static String _key(String name) => unquoteIdentifier(name, '`').toLowerCase();

  /// Adds [entry], of the columns [columns], to the last statement, or to a
  /// new one if one of them is renamed or added in it, or, for an entry
  /// [afterChanges], changed in it, as a statement renames or drops a column
  /// by its name before the statement, and changes it by that name too.
  void _add(
    Object entry,
    Iterable<String> columns, {
    bool afterChanges = false,
  }) {
    var last = _statements.last;
    if (columns.any(
      (c) =>
          last.introduced.contains(_key(c)) ||
          (afterChanges && last.modified.contains(_key(c))),
    )) {
      _statements.add(last = _AlterStatement(_currentName));
    }
    last.entries.add(entry);
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
    _add(_AddedColumn(name), [name]);
    _statements.last.introduced.add(_key(name));
    return col;
  }

  /// MySQL and MariaDB have no `ALTER COLUMN DROP NOT NULL`, so the column
  /// is defined again by a `MODIFY`, which keeps its type and constraints.
  @override
  void dropNotNull(String name) =>
      _modify(ColumnModification.nullability(name, isNullable: true));

  @override
  void setNotNull(String name) =>
      _modify(ColumnModification.nullability(name, isNullable: false));

  /// Adds [modification], or merges it into the one of its column before in
  /// the statement, as MySQL and MariaDB take one `MODIFY` of a column in a
  /// statement.
  void _modify(ColumnModification modification) {
    _add(modification, [modification.name]);
    var entries = _statements.last.entries;
    var key = _key(modification.name);
    var i = entries.indexWhere(
      (e) =>
          e is ColumnModification &&
          !identical(e, modification) &&
          _key(e.name) == key,
    );
    if (i >= 0) {
      entries[i] = (entries[i] as ColumnModification).mergedWith(modification);
      entries.removeLast();
    }
    _statements.last.modified.add(key);
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
    _modify(modification);
  }

  @override
  void renameColumn(String name, String newName) {
    _add(
      'RENAME COLUMN ${quoteMySqlIdentifier(name)} '
      'TO ${quoteMySqlIdentifier(newName)}',
      [name],
      afterChanges: true,
    );
    _statements.last.introduced.add(_key(newName));
  }

  @override
  void dropColumn(String name) {
    _add('DROP COLUMN ${quoteMySqlIdentifier(name)}', [
      name,
    ], afterChanges: true);
  }

  @override
  void rename(String newName) {
    _add('RENAME TO ${quoteMySqlTableName(newName)}', const []);
    _currentName = newName;
  }

  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    if (type == IndexType.primaryKey) checkPrimaryKeyColumns(columns);
    var ifNotExists = ifExists ? 'IF NOT EXISTS ' : '';
    var indexType = switch (type) {
      IndexType.primaryKey => 'PRIMARY KEY',
      IndexType.unique =>
        'UNIQUE INDEX $ifNotExists${quoteMySqlIdentifier(name)}',
      IndexType.standardIndex ||
      IndexType.none => 'INDEX $ifNotExists${quoteMySqlIdentifier(name)}',
    };
    _add(
      'ADD $indexType (${columns.map((c) => compileIndexColumn(c, quoteMySqlPart)).join(',')})',
      columns,
    );
  }

  @override
  void dropIndex(String name) {
    _add(
      'DROP INDEX ${ifExists ? 'IF EXISTS ' : ''}${quoteMySqlIdentifier(name)}',
      const [],
    );
  }

  @override
  void dropPrimaryIndex() {
    _add('DROP PRIMARY KEY', const []);
  }
}

/// An `ALTER TABLE` statement of a [ModifyingAlterTable], of the table named
/// [tableName] when it runs.
class _AlterStatement {
  final String tableName;

  /// Its clauses, a clause being SQL, a [ColumnModification] or an
  /// [_AddedColumn].
  final List<Object> entries = [];

  /// The columns renamed or added by it, by [ModifyingAlterTable._key].
  final Set<String> introduced = {};

  /// The columns changed by it, by [ModifyingAlterTable._key].
  final Set<String> modified = {};

  _AlterStatement(this.tableName);

  Iterable<ColumnModification> get modifications =>
      entries.whereType<ColumnModification>();
}

/// The `ADD COLUMN` of a column declared by a [ModifyingAlterTable], which is
/// compiled with its constraints when the table is.
class _AddedColumn {
  final String name;

  _AddedColumn(this.name);
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
    _buf.writeln('DROP TABLE ${quoteMySqlTableName(tableName)}$c;');
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
    _buf.writeln('CREATE TABLE$op ${quoteMySqlTableName(tableName)} (');
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
      table.compile(buf, indent);
    }
    buf.write(rest);
    return buf.toString();
  }

  /// Runs the SQL of the schema, whose text after the last alter table is
  /// [rest], with [execute], and reads the constraints with [query], which
  /// gives the rows of a query as text.
  ///
  /// The statements before an `ALTER TABLE` that changes a column are run
  /// before the column's constraints are read, as they may create the table,
  /// or add or rename the column.
  Future<void> run(
    StringBuffer rest, {
    required Future<void> Function(String sql) execute,
    required Future<List<List<String?>>> Function(String sql) query,
  }) async {
    Future<void> executeText(String sql) async {
      if (sql.trim().isNotEmpty) await execute(sql);
    }

    var reader = _ExistingReader(query);
    var buf = StringBuffer();
    for (var (text, table, indent) in _alters) {
      buf.write(text);
      for (var statement in table._statements) {
        // The constraints of a column are always read, as some, such as its
        // UNSIGNED or generation, cannot be given.
        if (statement.modifications.isNotEmpty) {
          await executeText(buf.toString());
          buf.clear();
          await reader.read(statement);
        }
        table._compileStatement(buf, statement, indent);
      }
    }
    buf.write(rest);
    await executeText(buf.toString());
  }
}

/// Reads the constraints of the columns changed by the statements of a run of
/// a schema, with the query of the run.
class _ExistingReader {
  final Future<List<List<String?>>> Function(String sql) query;

  /// Whether the server has `GENERATION_EXPRESSION`, until a query of it
  /// fails.
  bool _generationExpressions = true;

  _ExistingReader(this.query);

  /// Whether [error] is MySQL's error 1054, of an unknown column, whatever
  /// the language of its text: by the code of the exception of `mysql1` or
  /// `mysql_dart`, or else, of one that a caller wraps, by the code in its
  /// message. The only column of [existingConstraintsQuery] that a server may
  /// not have is `GENERATION_EXPRESSION`.
  ///
  /// Not by the name of the column, which an error of another kind, such as
  /// of the syntax, may quote from the query.
  static bool _isUnknownColumn(Object error) => switch (error) {
    MySqlException(:var errorNumber) => errorNumber == 1054,
    MySQLServerException(:var errorCode) => errorCode == 1054,
    _ => _unknownColumn.hasMatch('$error'),
  };

  /// The code of the error in the message of the clients: `Error 1054 (` of
  /// `mysql1`, `[1054]` of `mysql_dart`.
  static final RegExp _unknownColumn = RegExp(r'Error 1054 \(|\[1054\]');

  /// The rows of [existingConstraintsQuery] of [table] and [columns]. A server
  /// without `GENERATION_EXPRESSION`, MySQL before 5.7.6 or MariaDB before
  /// 10.2.5, rejects the query, which is made again without it.
  Future<List<List<String?>>> _constraints(
    String table,
    Set<String> columns,
  ) async {
    if (_generationExpressions) {
      try {
        return await query(existingConstraintsQuery(table, columns));
      } catch (e) {
        if (!_isUnknownColumn(e)) rethrow;
        _generationExpressions = false;
      }
    }
    return query(
      existingConstraintsQuery(table, columns, generationExpressions: false),
    );
  }

  /// Reads the constraints of the columns changed by [statement], which a
  /// `MODIFY` keeps only if it gives them again, from the database: in one
  /// query, and one more of their `CHECK` constraints on MariaDB.
  Future<void> read(_AlterStatement statement) async {
    var modifications = statement.modifications.toList();
    var columns = modifications.map((m) => m.name).toSet();
    var rows = await _constraints(statement.tableName, columns);
    // The names of columns are not case sensitive.
    var byName = {for (var row in rows) row[0]?.toLowerCase(): row};
    var version = rows.firstOrNull?[5] ?? '';
    var checks = {
      if (hasColumnChecks(version))
        for (var row in await query(
          columnChecksQuery(statement.tableName, columns, version: version),
        ))
          row[0]?.toLowerCase(): row[1],
    };
    for (var modification in modifications) {
      var row = byName[unquoteIdentifier(modification.name, '`').toLowerCase()];
      // Without them, the MODIFY would drop the constraints.
      if (row == null) {
        throw StateError(
          'Cannot change column ${modification.name} of table '
          '${statement.tableName}: it is not found in information_schema, so '
          'its constraints not given cannot be kept',
        );
      }
      modification.existing = ExistingConstraints.parse(
        isNullable: row[1] ?? 'YES',
        columnDefault: row[2],
        extra: row[3] ?? '',
        dataType: row[4] ?? '',
        version: row[5] ?? '',
        columnType: row[6],
        generationExpression: row[7],
        characterSet: row[8],
        collation: row[9],
        comment: row[10],
        check: checks[row[0]?.toLowerCase()],
        columnKey: row[11],
      );
    }
  }
}
