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
  final Queue<String> _stack = Queue<String>();

  /// The columns changed to a serial type, or to `autoIncrement`, with the
  /// integer type of their sequences.
  final Map<String, String> _sequences = {};

  PostgresAlterTable(this.tableName);

  void compile(StringBuffer buf, int indent) {
    // The changes and the columns added are clauses of one statement.
    var clauses = [
      ..._stack,
      for (var MapEntry(key: name, value: column) in _columns.entries)
        'ADD COLUMN ${sql.quotePostgresIdentifier(name)} ${PostgresGenerator.compileColumn(column)}',
    ];
    _stack.clear();
    buf.write(clauses.map((clause) => '${'  ' * indent}$clause').join(',\n'));
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
    var table = sql.quotePostgresIdentifier(tableName);
    _sequences.forEach((name, integer) {
      var column = '$table.${sql.quotePostgresIdentifier(name)}';
      var sequence = sql.quotePostgresIdentifier('${tableName}_${name}_seq');
      buf.writeln('''
DO \$\$
DECLARE
  seq_name text := pg_get_serial_sequence(${PostgresGenerator.compileDefault(table)}, ${PostgresGenerator.compileDefault(name)});
BEGIN
  IF seq_name IS NULL THEN
    CREATE SEQUENCE $sequence AS $integer OWNED BY $column;
    ALTER TABLE $table ALTER COLUMN ${sql.quotePostgresIdentifier(name)} SET DEFAULT nextval(${PostgresGenerator.compileDefault(sequence)});
    PERFORM setval(${PostgresGenerator.compileDefault(sequence)}, COALESCE((SELECT MAX(${sql.quotePostgresIdentifier(name)}) FROM $table), 0)::bigint + 1, false);
  ELSIF (SELECT t.typlen FROM pg_sequence s JOIN pg_type t ON t.oid = s.seqtypid
      WHERE s.seqrelid = seq_name::regclass) < ${_integerSizes[integer]} THEN
    EXECUTE format('ALTER SEQUENCE %s AS $integer', seq_name);
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
    return col;
  }

  @override
  void dropNotNull(String name) {
    _stack.add(
      'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} DROP NOT NULL',
    );
  }

  @override
  void setNotNull(String name) {
    _stack.add(
      'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} SET NOT NULL',
    );
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
    var integer = _serialIntegers[type];
    if (integer != null || autoIncrement == true) {
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
      _stack.add(
        'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} DROP DEFAULT',
      );
    }
    _stack.add(
      'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} TYPE ${PostgresGenerator.columnType(column)}'
      '${using == null ? '' : ' USING $using'}',
    );
    if (isNullable != null) {
      _stack.add(
        'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} ${isNullable ? 'DROP' : 'SET'} NOT NULL',
      );
    }
    if (defaultValue != null && !identical(defaultValue, noDefault)) {
      _stack.add(
        'ALTER COLUMN ${sql.quotePostgresIdentifier(name)} SET DEFAULT '
        '${PostgresGenerator.compileDefault(defaultValue)}',
      );
    }
  }

  /// The integer type of each serial type.
  static const Map<ColumnType, ColumnType> _serialIntegers = {
    ColumnType.smallSerial: ColumnType.smallInt,
    ColumnType.serial: ColumnType.int,
    ColumnType.bigSerial: ColumnType.bigInt,
  };

  /// The type of the sequence of each integer type.
  static const Map<ColumnType, String> _sequenceTypes = {
    ColumnType.tinyInt: 'smallint',
    ColumnType.smallInt: 'smallint',
    ColumnType.int: 'integer',
    ColumnType.bigInt: 'bigint',
  };

  @override
  void renameColumn(String name, String newName) {
    _stack.add(
      'RENAME COLUMN ${sql.quotePostgresIdentifier(name)} TO ${sql.quotePostgresIdentifier(newName)}',
    );
  }

  @override
  void dropColumn(String name) {
    _stack.add('DROP COLUMN ${sql.quotePostgresIdentifier(name)}');
  }

  @override
  void rename(String newName) {
    _stack.add('RENAME TO ${sql.quotePostgresIdentifier(newName)}');
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

    _stack.add('ADD $indexType (${columns.join(',')})');
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
          'ALTER TABLE ${sql.quotePostgresIdentifier(tableName)} ADD PRIMARY KEY (${columns.join(',')});',
        );
        break;
      case IndexType.unique:
        _stack.add(
          'CREATE UNIQUE INDEX IF NOT EXISTS ${sql.quotePostgresIdentifier(name)} '
          'ON ${sql.quotePostgresIdentifier(tableName)} (${columns.join(',')});',
        );
        break;
      //case IndexType.standardIndex:
      //case IndexType.none:
      default:
        _stack.add(
          'CREATE INDEX IF NOT EXISTS ${sql.quotePostgresIdentifier(name)} '
          'ON ${sql.quotePostgresIdentifier(tableName)} (${columns.join(',')});',
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
      'ALTER TABLE ${sql.quotePostgresIdentifier(tableName)} DROP CONSTRAINT ${sql.quotePostgresIdentifier('${tableName}_pkey')}',
    );
  }
}
