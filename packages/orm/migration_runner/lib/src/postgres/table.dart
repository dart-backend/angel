import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';

import '../change_column.dart';
import '../sql.dart' as sql;

abstract class PostgresGenerator {
  static String columnType(MigrationColumn column) {
    var str = column.type.name;
    // Without a precision or scale, an unbounded numeric.
    if (column.type.hasPrecision) {
      return '$str${column.precisionArguments(unbounded: true, maxPrecision: 1000)}';
    }
    if (column.type.hasLength) {
      return '$str(${column.length})';
    } else {
      return str;
    }
  }

  static String compileColumn(MigrationColumn column) {
    var buf = StringBuffer(columnType(column));

    if (column.isNullable == false) buf.write(' NOT NULL');
    var defaultValue = column.defaultValue;
    if (defaultValue != null) {
      buf.write(' DEFAULT ${compileDefault(defaultValue)}');
    }

    if (column.indexType == IndexType.unique) {
      buf.write(' UNIQUE');
    } else if (column.indexType == IndexType.primaryKey) {
      buf.write(' PRIMARY KEY');
    }

    for (var ref in column.externalReferences) {
      buf.write(' ${compileReference(ref)}');
    }

    return buf.toString();
  }

  /// The SQL of the default [value] of a column.
  static String compileDefault(Object value) => sql.compileDefault(
    value,
    escapeBackslashes: false,
    utcOffset: true,
    nonFinite: true,
  );

  static String compileReference(MigrationColumnReference ref) {
    var buf = StringBuffer(
      'REFERENCES ${sql.quotePostgresTableName(ref.foreignTable)}(${sql.quotePostgresIdentifier(ref.foreignKey)})',
    );
    if (ref.behavior != null) buf.write(' ${ref.behavior!}');
    return buf.toString();
  }
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
    '${sql.quotePostgresIdentifier(name)} '
    'ON ${sql.quotePostgresTableName(table)} '
    '(${columns.map((c) => sql.compileIndexColumn(c, sql.quotePostgresPart)).join(',')});';

/// The `DROP INDEX` of the index [name] of the table [table], which is of the
/// schema of the table, unless [name] is qualified by one.
String compileDropIndex(String table, String name, {bool ifExists = false}) {
  var parts = sql.postgresNameParts(name);
  var index = parts.length > 1
      ? sql.quotePostgresTableName(name)
      : sql.quotePostgresInSchemaOf(table, parts.single);
  return 'DROP INDEX ${ifExists ? 'IF EXISTS ' : ''}$index;';
}

/// The name of the index of the column [column] of the table [table], which is
/// declared with a standard index, as PostgreSQL names one,
/// `<table>_<column>_idx`, quoted.
String columnIndexName(String table, String column) => sql.quotePostgresPart(
  '${sql.unqualifiedPostgresName(table)}_'
  '${sql.unquoteIdentifier(column, '"')}_idx',
);

class PostgresTable extends Table {
  final _log = Logger('PostgresTable');

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
    var i = 0;

    _columns.forEach((name, column) {
      var col = PostgresGenerator.compileColumn(column);
      if (i++ > 0) buf.writeln(',');

      for (var i = 0; i < indent; i++) {
        buf.write('  ');
      }

      buf.write('${sql.quotePostgresIdentifier(name)} $col');
    });

    _log.fine(buf);
  }

  /// Compiles the `CREATE INDEX` of each column of the table [tableName]
  /// declared with a standard index, which PostgreSQL has no clause of a
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

class PostgresAlterTable extends Table implements MutableTable {
  final Map<String, MigrationColumn> _columns = {};
  final String tableName;

  /// The clauses, and the renames, which are statements of their own.
  final Queue<Object> _stack = Queue<Object>();

  /// The name of the table after the renames so far.
  String _currentName;

  /// The columns changed to a serial type, or to `autoIncrement`, by their
  /// names after the renames so far, with the integer type of their
  /// sequences.
  final Map<String, String> _sequences = {};

  /// The key of the column [name] in [_sequences], its own name, without its
  /// quotes, so that `'"Id"'` and `'Id'` are one column.
  static String _columnKey(String name) => sql.unquoteIdentifier(name, '"');

  /// The columns added in the statement so far, by [_columnKey].
  final Set<String> _added = {};

  PostgresAlterTable(this.tableName) : _currentName = tableName;

  /// Adds [clause], of the columns [columns], after a break if one of them is
  /// added in the statement so far.
  void _clause(String clause, Iterable<String> columns) {
    if (columns.map(_columnKey).any(_added.contains)) {
      _stack.add(_Break());
      _added.clear();
    }
    _stack.add(clause);
  }

  /// Adds [statement], which is a statement of its own.
  void _statement(_Statement statement) {
    _stack.add(statement);
    _added.clear();
  }

  /// Compiles the `ALTER TABLE` statements of the table, indented by
  /// [indent], which may be compiled again, as those of MySQL and MariaDB.
  ///
  /// PostgreSQL takes `RENAME COLUMN` and `RENAME TO` only as statements of
  /// their own, and `DROP COLUMN` is one too, so the clauses between them are
  /// one statement each, and those after a `RENAME TO` are of the new name.
  /// The columns added are clauses in the order they are declared, and a
  /// clause of a column added before it in its statement starts another, as
  /// the column does not exist before the statement.
  void compile(StringBuffer buf, int indent) {
    var table = tableName;
    var clauses = <String>[];
    // The columns added with a standard index, whose CREATE INDEX follows the
    // ALTER TABLE that adds them.
    var indexed = <String>[];
    void alter(Iterable<String> clauses) {
      if (clauses.isEmpty) return;
      buf.writeln(
        '${'  ' * indent}ALTER TABLE ${sql.quotePostgresTableName(table)}',
      );
      buf.write(clauses.map((c) => '${'  ' * (indent + 1)}$c').join(',\n'));
      buf.writeln(';');
      for (var name in indexed) {
        buf.writeln(
          '${'  ' * indent}'
          '${compileCreateIndex(columnIndexName(table, name), table, [name])}',
        );
      }
      indexed.clear();
    }

    for (var entry in _stack) {
      switch (entry) {
        case _Statement():
          alter(clauses);
          clauses = [];
          alter([entry.clause]);
          table = entry.newTableName ?? table;
        case _Break():
          alter(clauses);
          clauses = [];
        case _CreateIndex(:var name, :var columns, :var unique):
          // After the clauses before it, of the table as it is named then.
          alter(clauses);
          clauses = [];
          buf.writeln(
            '${'  ' * indent}'
            '${compileCreateIndex(name, table, columns, unique: unique)}',
          );
        case _DropIndex(:var name):
          // After the clauses before it, of the table as it is named then.
          alter(clauses);
          clauses = [];
          buf.writeln(_compileDropIndexOrConstraint(table, name));
        case _AddedColumn(:var name):
          var column = _columns[name]!;
          clauses.add(
            'ADD COLUMN ${sql.quotePostgresIdentifier(name)} '
            '${PostgresGenerator.compileColumn(column)}',
          );
          if (column.indexType == IndexType.standardIndex) indexed.add(name);
        default:
          clauses.add(entry as String);
      }
    }
    alter(clauses);
  }

  /// The statements after the `ALTER TABLE` that give each column changed to
  /// a serial type, or to `autoIncrement`, a default from a sequence of its
  /// own, if it has none, as `serial` does: the sequence is created, owned by
  /// the column, and starts after its greatest value.
  ///
  /// A sequence the column has, of a smaller integer than [_sequences] gives
  /// it, such as of a `serial` changed to `bigserial`, is changed to that
  /// integer, so that it does not end before the column's values do. Its
  /// greatest value is that of the integer, if it was that of the old one.
  void compileSequences(StringBuffer buf) {
    // The names after the renames, which run before.
    var table = sql.quotePostgresTableName(_currentName);
    var tableOwnName = sql.unqualifiedPostgresName(_currentName);
    // By the columns' own names, without their quotes, as the catalog knows
    // them.
    _sequences.forEach((name, integer) {
      var column = '$table.${sql.quotePostgresPart(name)}';
      // Of the schema of the table, as `serial` gives it.
      var sequence = sql.quotePostgresInSchemaOf(
        _currentName,
        '${tableOwnName}_${name}_seq',
      );
      var body =
          '''
DECLARE
  seq_name text := pg_get_serial_sequence(${sql.quoteLiteral(table)}, ${sql.quoteLiteral(name)});
BEGIN
  IF seq_name IS NULL THEN
    CREATE SEQUENCE $sequence AS $integer OWNED BY $column;
    ALTER TABLE $table ALTER COLUMN ${sql.quotePostgresPart(name)} SET DEFAULT nextval(${sql.quoteLiteral(sequence)});
    PERFORM setval(${sql.quoteLiteral(sequence)}, COALESCE((SELECT MAX(${sql.quotePostgresPart(name)}) FROM $table), 0)::bigint + 1, false);
  ELSE
    IF (SELECT t.typlen FROM pg_sequence s JOIN pg_type t ON t.oid = s.seqtypid
        WHERE s.seqrelid = seq_name::regclass) < ${_integerSizes[integer]} THEN
      EXECUTE format('ALTER SEQUENCE %s AS $integer', seq_name);
    END IF;
    -- A column whose default was dropped keeps its sequence, of which it
    -- gets the default again. An identity column has no default, but its
    -- identity, which takes none.
    IF NOT EXISTS (SELECT 1 FROM pg_attrdef d JOIN pg_attribute a
        ON a.attrelid = d.adrelid AND a.attnum = d.adnum
        WHERE d.adrelid = ${sql.quoteLiteral(table)}::regclass
        AND a.attname = ${sql.quoteLiteral(name)})
      AND NOT EXISTS (SELECT 1 FROM pg_attribute a
        WHERE a.attrelid = ${sql.quoteLiteral(table)}::regclass
        AND a.attname = ${sql.quoteLiteral(name)}
        AND a.attidentity <> '') THEN
      EXECUTE format('ALTER TABLE %s ALTER COLUMN %s SET DEFAULT nextval(%L::regclass)', ${sql.quoteLiteral(table)}, ${sql.quoteLiteral(sql.quotePostgresPart(name))}, seq_name);
    END IF;
  END IF;
END
''';
      buf.writeln(_doBlock('sequence', body));
    });
  }

  /// The `DO` block that drops the index [name] of the table [table]: a
  /// unique constraint, as [addIndex] adds one, or else a standard index,
  /// which PostgreSQL drops with a `DROP INDEX`. It raises an error if the
  /// table has neither, as a name with a typo would, so that the migration
  /// is not recorded as run.
  static String _compileDropIndexOrConstraint(String table, String name) {
    var constraint = sql.unquoteIdentifier(name, '"');
    var index = compileDropIndex(table, name);
    // The index of the DROP INDEX, without its `DROP INDEX ` and `;`.
    var indexName = index.substring('DROP INDEX '.length, index.length - 1);
    return _doBlock('index', '''
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint
      WHERE conrelid = ${sql.quoteLiteral(sql.quotePostgresTableName(table))}::regclass
      AND conname = ${sql.quoteLiteral(constraint)}) THEN
    ALTER TABLE ${sql.quotePostgresTableName(table)} DROP CONSTRAINT ${sql.quotePostgresPart(constraint)};
  ELSIF EXISTS (SELECT 1 FROM pg_class
      WHERE oid = to_regclass(${sql.quoteLiteral(indexName)})
      AND relkind IN ('i', 'I')) THEN
    $index
  ELSE
    RAISE EXCEPTION 'No index or constraint % of table %', ${sql.quoteLiteral(constraint)}, ${sql.quoteLiteral(sql.quotePostgresTableName(table))};
  END IF;
END
''');
  }

  /// The `DO` block of [body], quoted by a tag of [name] that the names in it
  /// do not have, which would end it.
  static String _doBlock(String name, String body) {
    var tag = '\$$name\$';
    for (var i = 1; body.contains(tag); i++) {
      tag = '\$$name$i\$';
    }
    return 'DO $tag\n$body$tag;';
  }

  /// The size in bytes of each integer type of a sequence.
  static const Map<String, int> _integerSizes = {
    'smallint': 2,
    'integer': 4,
    'bigint': 8,
  };

  @override
  MigrationColumn declareColumn(String name, Column column) {
    if (_columns.containsKey(name)) {
      throw StateError('Cannot redeclare column "$name".');
    }
    var col = MigrationColumn.from(column);
    _columns[name] = col;
    _stack.add(_AddedColumn(name));
    _added.add(_columnKey(name));
    return col;
  }

  @override
  void dropNotNull(String name) {
    _clause('ALTER COLUMN ${sql.quotePostgresIdentifier(name)} DROP NOT NULL', [
      name,
    ]);
  }

  @override
  void setNotNull(String name) {
    _clause('ALTER COLUMN ${sql.quotePostgresIdentifier(name)} SET NOT NULL', [
      name,
    ]);
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
    // A serial type is not a type that a column can be changed to, but an
    // integer with a default from a sequence, which a serial column keeps,
    // and which compileSequences gives a column without one.
    // With `autoIncrement: false`, a serial type is only its integer, as on
    // MySQL and MariaDB, and so it is with `noDefault`, the default from its
    // sequence being one, unless `autoIncrement: true` is given.
    var integer = sql.serialIntegers[type];
    var serial =
        integer != null &&
        autoIncrement != false &&
        !identical(defaultValue, noDefault);
    if (serial || autoIncrement == true) {
      _sequences[_columnKey(name)] =
          _sequenceTypes[integer ?? type] ?? 'bigint';
    }
    var column = changedColumn(
      integer ?? type,
      length: length,
      precision: precision,
      scale: scale,
    );
    // The column keeps its constraints, and gets those given. A new default,
    // or noDefault, replaces the old one, which is dropped first, as it may
    // not be cast to the new type.
    if (defaultValue != null) {
      _clause(
        'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} DROP DEFAULT',
        [name],
      );
    }
    _clause(
      'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} TYPE ${PostgresGenerator.columnType(column)}'
      '${using == null ? '' : ' USING $using'}',
      [name],
    );
    if (isNullable != null) {
      _clause(
        'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} ${isNullable ? 'DROP' : 'SET'} NOT NULL',
        [name],
      );
    }
    if (defaultValue != null && !identical(defaultValue, noDefault)) {
      _clause(
        'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} SET DEFAULT '
        '${PostgresGenerator.compileDefault(defaultValue)}',
        [name],
      );
    }
  }

  /// The type of the sequence of each integer type.
  static const Map<ColumnType, String> _sequenceTypes = {
    ColumnType.tinyInt: 'smallint',
    ColumnType.smallInt: 'smallint',
    ColumnType.int: 'integer',
    ColumnType.bigInt: 'bigint',
  };

  @override
  void renameColumn(String name, String newName) {
    _statement(
      _Statement(
        'RENAME COLUMN ${sql.quotePostgresIdentifier(name)} '
        'TO ${sql.quotePostgresIdentifier(newName)}',
      ),
    );
    // A column changed to a serial type before is given its sequence by its
    // new name.
    var integer = _sequences.remove(_columnKey(name));
    if (integer != null) _sequences[_columnKey(newName)] = integer;
  }

  @override
  void dropColumn(String name) {
    // A statement of its own, as PostgreSQL rejects the changes of a column
    // with its drop in one.
    _statement(_Statement('DROP COLUMN ${sql.quotePostgresIdentifier(name)}'));
    _sequences.remove(_columnKey(name));
  }

  @override
  void rename(String newName) {
    // Throws for a new name of another schema, which RENAME TO cannot move
    // the table to, before the clause is added.
    var renamed = sql.renamedPostgresTable(_currentName, newName);
    // RENAME TO takes the table's own name, without its schema.
    _statement(
      _Statement(
        'RENAME TO '
        '${sql.quotePostgresPart(sql.unqualifiedPostgresName(newName))}',
        newTableName: renamed,
      ),
    );
    _currentName = renamed;
  }

  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    String indexType = '';

    switch (type) {
      case IndexType.primaryKey:
        sql.checkPrimaryKeyColumns(columns);
        indexType = 'PRIMARY KEY';
        break;
      case IndexType.unique:
        // A constraint is of columns only, so a unique index of an
        // expression, or with an order, is a unique index, as `indexes`
        // creates it.
        if (!columns.every(sql.isIndexColumnName)) {
          _stack.add(_CreateIndex(name, columns, unique: true));
          _added.clear();
          return;
        }
        indexType = 'CONSTRAINT ${sql.quotePostgresIdentifier(name)} UNIQUE';
        break;
      case IndexType.standardIndex:
      case IndexType.none:
        // Not a clause of ALTER TABLE on PostgreSQL, but a statement of its
        // own, after those before it, so that its columns are added.
        _stack.add(_CreateIndex(name, columns));
        _added.clear();
        return;
    }

    _clause(
      'ADD $indexType (${columns.map((c) => sql.compileIndexColumn(c, sql.quotePostgresPart)).join(',')})',
      columns,
    );
  }

  @override
  void dropIndex(String name) {
    _stack.add(_DropIndex(name));
    _added.clear();
  }

  @override
  void dropPrimaryIndex() {
    _stack.add(
      'DROP CONSTRAINT ${sql.quotePostgresPart('${sql.unqualifiedPostgresName(tableName)}_pkey')}',
    );
  }
}

/// A clause that is a statement of its own: a `RENAME COLUMN` or `RENAME TO`,
/// which PostgreSQL takes with no other clause, or a `DROP COLUMN`, and the
/// new name of the table, if it is renamed.
class _Statement {
  final String clause;
  final String? newTableName;

  _Statement(this.clause, {this.newTableName});
}

/// The end of a statement of a [PostgresAlterTable], before a clause of a
/// column added in it.
class _Break {}

/// An index dropped by a [PostgresAlterTable]: a unique constraint, or a
/// standard index, which PostgreSQL drops with a `DROP INDEX` of its own.
class _DropIndex {
  final String name;

  _DropIndex(this.name);
}

/// A standard index added by a [PostgresAlterTable], which PostgreSQL creates
/// with a `CREATE INDEX` of its own, not a clause of `ALTER TABLE`.
class _CreateIndex {
  final String name;
  final List<String> columns;
  final bool unique;

  _CreateIndex(this.name, this.columns, {this.unique = false});
}

/// The `ADD COLUMN` of a column declared by a [PostgresAlterTable], which is
/// compiled with its constraints when the table is.
class _AddedColumn {
  final String name;

  _AddedColumn(this.name);
}

class PostgresIndexes implements MutableIndexes {
  final String tableName;
  final Queue<String> _stack = Queue<String>();

  PostgresIndexes(this.tableName);

  /// Compiles the statements of the indexes, which may be compiled again.
  void compile(StringBuffer buf) {
    for (var statement in _stack) {
      buf.writeln(statement);
    }
  }

  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    switch (type) {
      case IndexType.primaryKey:
        sql.checkPrimaryKeyColumns(columns);
        _stack.add(
          'ALTER TABLE ${sql.quotePostgresTableName(tableName)} ADD PRIMARY KEY (${columns.map((c) => sql.compileIndexColumn(c, sql.quotePostgresPart)).join(',')});',
        );
        break;
      case IndexType.unique:
        _stack.add(compileCreateIndex(name, tableName, columns, unique: true));
        break;
      //case IndexType.standardIndex:
      //case IndexType.none:
      default:
        _stack.add(compileCreateIndex(name, tableName, columns));
        break;
    }
  }

  @override
  void dropIndex(String name) {
    // An index is of the schema of its table, unless one is given.
    _stack.add(compileDropIndex(tableName, name));
  }

  @override
  void dropPrimaryIndex() {
    _stack.add(
      'ALTER TABLE ${sql.quotePostgresTableName(tableName)} DROP CONSTRAINT ${sql.quotePostgresPart('${sql.unqualifiedPostgresName(tableName)}_pkey')};',
    );
  }
}
