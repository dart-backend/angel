import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';

import '../sql.dart' as sql;

/// Compiles the columns, defaults and indexes of SQLite.
///
/// Names are quoted as PostgreSQL quotes them, in double quotes, which SQLite
/// takes too; a table may be qualified by the schema of an attached database,
/// such as `main.users`.
abstract class SqliteGenerator {
  /// The SQLite type of [column], whose affinity is that of its values: an
  /// integer is `INTEGER`, so that one of a primary key is the rowid, a date
  /// or time `TEXT`, as `angel3_orm_sqlite` stores it, and a binary `BLOB`.
  /// Another type is as it is named.
  ///
  /// Throws an [UnsupportedError] for a serial type that is not of a primary
  /// key, as SQLite generates only the values of an `INTEGER PRIMARY KEY`.
  static String columnType(MigrationColumn column) {
    var type = column.type;
    if (sql.serialIntegers.containsKey(type)) {
      if (column.indexType != IndexType.primaryKey) {
        throw UnsupportedError(
          'SQLite generates only the values of an INTEGER PRIMARY KEY: a '
          '${type.name} column must be the primary key.',
        );
      }
      return 'INTEGER';
    }
    if (_integers.contains(type)) return 'INTEGER';
    if (_reals.contains(type)) return 'REAL';
    if (_texts.contains(type)) return 'TEXT';
    if (_blobs.contains(type)) return 'BLOB';
    if (type == ColumnType.boolean) return 'BOOLEAN';
    if (type.hasPrecision) {
      return '${type.name.toUpperCase()}${column.precisionArguments()}';
    }
    if (type.hasLength) return '${type.name.toUpperCase()}(${column.length})';
    if (type == ColumnType.cursor || type == ColumnType.table) {
      throw UnsupportedError('SQLite has no ${type.name} column.');
    }
    return type.name.toUpperCase();
  }

  static const Set<ColumnType> _integers = {
    ColumnType.tinyInt,
    ColumnType.smallInt,
    ColumnType.int,
    ColumnType.bigInt,
    ColumnType.bit,
  };

  static const Set<ColumnType> _reals = {
    ColumnType.float,
    ColumnType.real,
    ColumnType.double,
  };

  static const Set<ColumnType> _texts = {
    ColumnType.dateTime,
    ColumnType.smallDateTime,
    ColumnType.date,
    ColumnType.time,
    ColumnType.timeStamp,
    ColumnType.timeStampWithTimeZone,
    ColumnType.varCharMax,
    ColumnType.nVarCharMax,
    ColumnType.text,
    ColumnType.nText,
    ColumnType.json,
    ColumnType.jsonb,
    ColumnType.uniqueIdentifier,
    ColumnType.uuid,
    ColumnType.xml,
  };

  static const Set<ColumnType> _blobs = {
    ColumnType.binary,
    ColumnType.varBinary,
    ColumnType.varBinaryMax,
    ColumnType.image,
  };

  /// The definition of [column], after its name. A serial primary key is an
  /// `INTEGER PRIMARY KEY AUTOINCREMENT`, whose ids are never used again.
  ///
  /// Without [constraints], it has no `UNIQUE` and no `PRIMARY KEY`, which
  /// SQLite does not add to a table, and throws an [UnsupportedError] for a
  /// primary key.
  static String compileColumn(
    MigrationColumn column, {
    bool constraints = true,
  }) {
    var buf = StringBuffer(columnType(column));
    var serial = sql.serialIntegers.containsKey(column.type);

    if (column.indexType == IndexType.primaryKey) {
      if (!constraints) {
        throw UnsupportedError(
          'SQLite cannot add a PRIMARY KEY column to a table.',
        );
      }
      buf.write(' PRIMARY KEY');
      if (serial) buf.write(' AUTOINCREMENT');
    }
    if (column.isNullable == false) buf.write(' NOT NULL');
    var defaultValue = column.defaultValue;
    if (defaultValue != null) {
      buf.write(' DEFAULT ${compileDefault(defaultValue)}');
    }
    if (constraints && column.indexType == IndexType.unique) {
      buf.write(' UNIQUE');
    }

    for (var ref in column.externalReferences) {
      buf.write(' ${compileReference(ref)}');
    }

    return buf.toString();
  }

  /// The SQL of the default [value] of a column. A [DateTime] is UTC text, as
  /// `angel3_orm_sqlite` stores one (`'2024-03-10 12:34:56.000000Z'`), and so
  /// is `currentTimestamp`, where SQLite's `CURRENT_TIMESTAMP` would give UTC
  /// without its `Z`, which Dart reads as local time.
  ///
  /// Throws an [ArgumentError] for a `double` that is not finite, which SQLite
  /// does not store, and for a [DateTime] of a year before 0 or after 9999.
  static String compileDefault(Object value) {
    if (value is double && !value.isFinite) {
      throw ArgumentError.value(value, null, 'SQLite has no NaN or infinity');
    }
    if (value is DateTime) {
      return sql.quoteLiteral(SqliteDialect.formatDateTime(value));
    }
    if (value is RawSql &&
        value.value.trim().toUpperCase() == 'CURRENT_TIMESTAMP') {
      return "(strftime('%Y-%m-%d %H:%M:%f', 'now') || '000Z')";
    }
    return sql.compileDefault(value, escapeBackslashes: false);
  }

  /// A `REFERENCES` of [ref], of a table of the same database, as SQLite
  /// takes no schema there.
  static String compileReference(MigrationColumnReference ref) {
    var table = sql.quotePostgresPart(
      sql.unqualifiedPostgresName(ref.foreignTable),
    );
    var buf = StringBuffer(
      'REFERENCES $table(${sql.quotePostgresIdentifier(ref.foreignKey)})',
    );
    if (ref.behavior != null) buf.write(' ${ref.behavior!}');
    return buf.toString();
  }
}

/// The index [name], in the schema of the table [table] unless it is
/// qualified by one, quoted, as SQLite names an index in its schema.
String _indexName(String table, String name) {
  var parts = sql.postgresNameParts(name);
  return parts.length > 1
      ? sql.quotePostgresTableName(name)
      : sql.quotePostgresInSchemaOf(table, parts.single);
}

/// The `CREATE INDEX` of the index [name] of the [columns] of the table
/// [table], which may be qualified by its schema, if it does not exist.
String compileCreateIndex(
  String name,
  String table,
  List<String> columns, {
  bool unique = false,
}) =>
    'CREATE ${unique ? 'UNIQUE ' : ''}INDEX IF NOT EXISTS '
    '${_indexName(table, name)} '
    // Of the schema of the index, which takes the table without one.
    'ON ${sql.quotePostgresPart(sql.unqualifiedPostgresName(table))} '
    '(${columns.map((c) => sql.compileIndexColumn(c, sql.quotePostgresPart)).join(', ')});';

/// The `DROP INDEX` of the index [name] of the table [table].
String compileDropIndex(String table, String name) =>
    'DROP INDEX ${_indexName(table, name)};';

/// The name of the index of the column [column] of the table [table],
/// `<table>_<column>_idx`, as PostgreSQL names one, or, if [unique],
/// `<table>_<column>_key`.
String columnIndexName(String table, String column, {bool unique = false}) =>
    '${sql.unqualifiedPostgresName(table)}_'
    '${sql.unquoteIdentifier(column, '"')}_${unique ? 'key' : 'idx'}';

UnsupportedError _rebuildNeeded(String change) => UnsupportedError(
  'SQLite cannot $change with ALTER TABLE. Create a table with the new '
  'definition, copy the rows into it, drop the old table and rename the new '
  'one, as https://www.sqlite.org/lang_altertable.html#otheralter describes.',
);

class SqliteTable extends Table {
  final Map<String, MigrationColumn> _columns = {};

  @override
  MigrationColumn declareColumn(String name, Column column) {
    if (_columns.containsKey(name)) {
      throw StateError('Cannot redeclare column "$name".');
    }
    var col = MigrationColumn.from(column);
    _columns[name] = col;
    return col;
  }

  void compile(StringBuffer buf, int indent) {
    buf.write(
      _columns.entries
          .map(
            (e) =>
                '${'  ' * indent}${sql.quotePostgresIdentifier(e.key)} '
                '${SqliteGenerator.compileColumn(e.value)}',
          )
          .join(',\n'),
    );
  }

  /// Compiles the `CREATE INDEX` of each column of the table [tableName]
  /// declared with a standard index, which SQLite has no clause of a
  /// `CREATE TABLE` for, indented by [indent].
  void compileIndexes(StringBuffer buf, String tableName, int indent) {
    _columns.forEach((name, column) {
      if (column.indexType == IndexType.standardIndex) {
        buf.writeln(
          '${'  ' * indent}'
          '${compileCreateIndex(columnIndexName(tableName, name), tableName, [name])}',
        );
      }
    });
  }
}

/// The changes of a table, each an `ALTER TABLE`, a `CREATE INDEX` or a
/// `DROP INDEX` of its own, in the order they are given, as SQLite takes one
/// change in an `ALTER TABLE`.
///
/// SQLite can rename the table, add, rename and drop a column, and add and
/// drop an index. The other changes throw an [UnsupportedError], as SQLite
/// makes them only by creating the table again.
class SqliteAlterTable extends Table implements MutableTable {
  final String tableName;

  /// The statements, compiled when the table is, as a column declared may be
  /// changed after, as by `notNull()`.
  final List<String Function()> _statements = [];

  /// The name of the table after the renames so far.
  String _currentName;

  final Set<String> _declared = {};

  SqliteAlterTable(this.tableName) : _currentName = tableName;

  String get _table => sql.quotePostgresTableName(_currentName);

  void _alter(String clause) {
    var statement = 'ALTER TABLE $_table $clause;';
    _statements.add(() => statement);
  }

  /// Compiles the statements of the table, indented by [indent], which may
  /// be compiled again.
  void compile(StringBuffer buf, int indent) {
    for (var statement in _statements) {
      for (var line in statement().split('\n')) {
        buf.writeln('${'  ' * indent}$line');
      }
    }
  }

  /// Adds the column [name], without a `UNIQUE`, which SQLite does not add,
  /// but with a unique index of its own, as with a standard index.
  @override
  MigrationColumn declareColumn(String name, Column column) {
    if (!_declared.add(name)) {
      throw StateError('Cannot redeclare column "$name".');
    }
    var col = MigrationColumn.from(column);
    var table = _currentName;
    _statements.add(() {
      var buf = StringBuffer(
        'ALTER TABLE ${sql.quotePostgresTableName(table)} '
        'ADD COLUMN ${sql.quotePostgresIdentifier(name)} '
        '${SqliteGenerator.compileColumn(col, constraints: false)};',
      );
      if (col.indexType case IndexType.unique || IndexType.standardIndex) {
        var unique = col.indexType == IndexType.unique;
        buf.write(
          '\n${compileCreateIndex(columnIndexName(table, name, unique: unique), table, [name], unique: unique)}',
        );
      }
      return buf.toString();
    });
    return col;
  }

  @override
  void rename(String newName) {
    // Throws for a new name of another schema, which RENAME TO cannot move
    // the table to.
    var renamed = sql.renamedPostgresTable(_currentName, newName);
    _alter(
      'RENAME TO ${sql.quotePostgresPart(sql.unqualifiedPostgresName(newName))}',
    );
    _currentName = renamed;
  }

  @override
  void renameColumn(String name, String newName) => _alter(
    'RENAME COLUMN ${sql.quotePostgresIdentifier(name)} '
    'TO ${sql.quotePostgresIdentifier(newName)}',
  );

  /// Drops the column [name], which SQLite does only of a column that is not
  /// of a primary key, a unique constraint, an index or a foreign key.
  @override
  void dropColumn(String name) =>
      _alter('DROP COLUMN ${sql.quotePostgresIdentifier(name)}');

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
  }) => throw _rebuildNeeded('change the type of a column');

  @override
  void dropNotNull(String name) => throw _rebuildNeeded('drop a NOT NULL');

  @override
  void setNotNull(String name) => throw _rebuildNeeded('set a NOT NULL');

  /// Adds a unique or a standard index of [columns]. Throws an
  /// [UnsupportedError] for a primary key, which SQLite adds to no table.
  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    if (type == IndexType.primaryKey) {
      throw _rebuildNeeded('add a primary key');
    }
    var table = _currentName;
    var statement = compileCreateIndex(
      name,
      table,
      columns,
      unique: type == IndexType.unique,
    );
    _statements.add(() => statement);
  }

  @override
  void dropIndex(String name) {
    var statement = compileDropIndex(_currentName, name);
    _statements.add(() => statement);
  }

  @override
  void dropPrimaryIndex() => throw _rebuildNeeded('drop a primary key');
}

class SqliteIndexes implements MutableIndexes {
  final String tableName;
  final List<String> _statements = [];

  SqliteIndexes(this.tableName);

  /// Compiles the statements of the indexes, which may be compiled again.
  void compile(StringBuffer buf) {
    for (var statement in _statements) {
      buf.writeln(statement);
    }
  }

  /// Adds a unique or a standard index of [columns]. Throws an
  /// [UnsupportedError] for a primary key, which SQLite adds to no table.
  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    if (type == IndexType.primaryKey) {
      throw _rebuildNeeded('add a primary key');
    }
    _statements.add(
      compileCreateIndex(
        name,
        tableName,
        columns,
        unique: type == IndexType.unique,
      ),
    );
  }

  @override
  void dropIndex(String name) =>
      _statements.add(compileDropIndex(tableName, name));

  @override
  void dropPrimaryIndex() => throw _rebuildNeeded('drop a primary key');
}
