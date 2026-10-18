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
  static String compileDefault(Object value) =>
      sql.compileDefault(value, escapeBackslashes: false);

  static String compileReference(MigrationColumnReference ref) {
    var buf = StringBuffer(
      'REFERENCES ${sql.quotePostgresIdentifier(ref.foreignTable)}(${sql.quotePostgresIdentifier(ref.foreignKey)})',
    );
    if (ref.behavior != null) buf.write(' ${ref.behavior!}');
    return buf.toString();
  }
}

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

  /// The columns added in the statement so far.
  final Set<String> _added = {};

  PostgresAlterTable(this.tableName) : _currentName = tableName;

  /// Adds [clause], of the columns [columns], after a break if one of them is
  /// added in the statement so far.
  void _clause(String clause, Iterable<String> columns) {
    if (columns.any(_added.contains)) {
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
  /// [indent].
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
    void alter(Iterable<String> clauses) {
      if (clauses.isEmpty) return;
      buf.writeln(
        '${'  ' * indent}ALTER TABLE ${sql.quotePostgresIdentifier(table)}',
      );
      buf.write(clauses.map((c) => '${'  ' * (indent + 1)}$c').join(',\n'));
      buf.writeln(';');
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
        case _AddedColumn(:var name):
          clauses.add(
            'ADD COLUMN ${sql.quotePostgresIdentifier(name)} '
            '${PostgresGenerator.compileColumn(_columns[name]!)}',
          );
        default:
          clauses.add(entry as String);
      }
    }
    alter(clauses);
    _stack.clear();
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
    var table = sql.quotePostgresIdentifier(_currentName);
    _sequences.forEach((name, integer) {
      var column = '$table.${sql.quotePostgresIdentifier(name)}';
      var sequence = sql.quotePostgresIdentifier('${_currentName}_${name}_seq');
      buf.writeln('''
DO \$\$
DECLARE
  seq_name text := pg_get_serial_sequence(${PostgresGenerator.compileDefault(table)}, ${PostgresGenerator.compileDefault(name)});
BEGIN
  IF seq_name IS NULL THEN
    CREATE SEQUENCE $sequence AS $integer OWNED BY $column;
    ALTER TABLE $table ALTER COLUMN ${sql.quotePostgresIdentifier(name)} SET DEFAULT nextval(${PostgresGenerator.compileDefault(sequence)});
    PERFORM setval(${PostgresGenerator.compileDefault(sequence)}, COALESCE((SELECT MAX(${sql.quotePostgresIdentifier(name)}) FROM $table), 0)::bigint + 1, false);
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
        WHERE d.adrelid = ${PostgresGenerator.compileDefault(table)}::regclass
        AND a.attname = ${PostgresGenerator.compileDefault(name)})
      AND NOT EXISTS (SELECT 1 FROM pg_attribute a
        WHERE a.attrelid = ${PostgresGenerator.compileDefault(table)}::regclass
        AND a.attname = ${PostgresGenerator.compileDefault(name)}
        AND a.attidentity <> '') THEN
      EXECUTE format('ALTER TABLE ${table.replaceAll('%', '%%')} ALTER COLUMN ${sql.quotePostgresIdentifier(name).replaceAll('%', '%%')} SET DEFAULT nextval(%L::regclass)', seq_name);
    END IF;
  END IF;
END
\$\$;''');
    });
    _sequences.clear();
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
    _added.add(name);
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
    // MySQL and MariaDB.
    var integer = sql.serialIntegers[type];
    if ((integer != null && autoIncrement != false) || autoIncrement == true) {
      _sequences[name] = _sequenceTypes[integer ?? type] ?? 'bigint';
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
    var integer = _sequences.remove(name);
    if (integer != null) _sequences[newName] = integer;
  }

  @override
  void dropColumn(String name) {
    // A statement of its own, as PostgreSQL rejects the changes of a column
    // with its drop in one.
    _statement(_Statement('DROP COLUMN ${sql.quotePostgresIdentifier(name)}'));
    _sequences.remove(name);
  }

  @override
  void rename(String newName) {
    _statement(
      _Statement(
        'RENAME TO ${sql.quotePostgresIdentifier(newName)}',
        newTableName: newName,
      ),
    );
    _currentName = newName;
  }

  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    String indexType = '';

    switch (type) {
      case IndexType.primaryKey:
        indexType = 'PRIMARY KEY';
        break;
      case IndexType.unique:
        indexType = 'CONSTRAINT ${sql.quotePostgresIdentifier(name)} UNIQUE';
        break;
      case IndexType.standardIndex:
      case IndexType.none:
        // not working with postgres
        return;
    }

    _clause(
      'ADD $indexType (${columns.map((c) => sql.compileIndexColumn(c, sql.quotePostgresIdentifier)).join(',')})',
      columns,
    );
  }

  @override
  void dropIndex(String name) {
    _stack.add('DROP CONSTRAINT ${sql.quotePostgresIdentifier(name)}');
  }

  @override
  void dropPrimaryIndex() {
    _stack.add(
      'DROP CONSTRAINT ${sql.quotePostgresIdentifier('${tableName}_pkey')}',
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

  void compile(StringBuffer buf) {
    while (_stack.isNotEmpty) {
      buf.writeln(_stack.removeFirst());
    }
  }

  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    switch (type) {
      case IndexType.primaryKey:
        _stack.add(
          'ALTER TABLE ${sql.quotePostgresIdentifier(tableName)} ADD PRIMARY KEY (${columns.map((c) => sql.compileIndexColumn(c, sql.quotePostgresIdentifier)).join(',')});',
        );
        break;
      case IndexType.unique:
        _stack.add(
          'CREATE UNIQUE INDEX IF NOT EXISTS ${sql.quotePostgresIdentifier(name)} '
          'ON ${sql.quotePostgresIdentifier(tableName)} (${columns.map((c) => sql.compileIndexColumn(c, sql.quotePostgresIdentifier)).join(',')});',
        );
        break;
      //case IndexType.standardIndex:
      //case IndexType.none:
      default:
        _stack.add(
          'CREATE INDEX IF NOT EXISTS ${sql.quotePostgresIdentifier(name)} '
          'ON ${sql.quotePostgresIdentifier(tableName)} (${columns.map((c) => sql.compileIndexColumn(c, sql.quotePostgresIdentifier)).join(',')});',
        );
        break;
    }
  }

  @override
  void dropIndex(String name) {
    _stack.add('DROP INDEX ${sql.quotePostgresIdentifier(name)};');
  }

  @override
  void dropPrimaryIndex() {
    _stack.add(
      'ALTER TABLE ${sql.quotePostgresIdentifier(tableName)} DROP CONSTRAINT ${sql.quotePostgresIdentifier('${tableName}_pkey')};',
    );
  }
}
