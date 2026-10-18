import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';

import '../mysql_family.dart';
import '../sql.dart';

abstract class MariaDbGenerator {
  static String columnType(MigrationColumn column) {
    var str = column.type.name;

    /*
    // Handle reference key to serial
    if (str.toLowerCase() == ColumnType.int.name) {
      if (column.externalReferences.isNotEmpty) {

        return 'BIGINT UNSIGNED';
      }
    }
    */

    // A serial type is an integer, with AUTO_INCREMENT.
    var integer = serialIntegers[column.type];
    if (integer != null) return integer.name;

    // Map timestamp time to datetime
    if (column.type == ColumnType.timeStamp) {
      str = ColumnType.dateTime.name;
    }
    // MariaDB has no numeric without a precision, whose default rounds values
    // to whole numbers, so a column without one has Column.defaultPrecision.
    if (column.type.hasPrecision) {
      return '$str${column.precisionArguments(maxPrecision: 65, maxScale: 38)}';
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

  static String compileReference(MigrationColumnReference ref) {
    var buf = StringBuffer('REFERENCES ${ref.foreignTable}(${ref.foreignKey})');
    if (ref.behavior != null) buf.write(' ${ref.behavior!}');
    return buf.toString();
  }
}

class MariaDbTable extends CompiledTable {
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

  @override
  void compile(StringBuffer buf, int indent) {
    var i = 0;
    List indexBuf = [];

    _columns.forEach((name, column) {
      var col = MariaDbGenerator.compileColumn(column);
      if (i++ > 0) buf.writeln(',');

      for (var i = 0; i < indent; i++) {
        buf.write('  ');
      }

      buf.write('${quoteMySqlIdentifier(name)} $col');

      var index = MariaDbGenerator.compileIndex(name, column);
      if (index != null) indexBuf.add(index);
    });

    if (indexBuf.isNotEmpty) {
      for (var i = 0; i < indexBuf.length; i++) {
        buf.write(',\n${indexBuf[i]}');
      }
    }
  }
}

class MariaDbAlterTable extends ModifyingAlterTable {
  MariaDbAlterTable(String tableName)
    : super(tableName, MariaDbGenerator.compileColumn, ifExists: true);
}

class MariaDbIndexes implements CompiledIndexes {
  final String tableName;
  final Queue<String> _stack = Queue<String>();

  MariaDbIndexes(this.tableName);

  @override
  void compile(StringBuffer buf) {
    while (_stack.isNotEmpty) {
      var str = _stack.removeFirst();
      buf.writeln(str);
    }
  }

  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    // mask the column names, is more safety
    columns = columns.map(quoteMySqlIdentifier).toList();

    switch (type) {
      case IndexType.primaryKey:
        _stack.add(
          'ALTER TABLE ${quoteMySqlIdentifier(tableName)} ADD PRIMARY KEY (${columns.join(',')});',
        );
        break;
      case IndexType.unique:
        _stack.add(
          'CREATE UNIQUE INDEX IF NOT EXISTS ${quoteMySqlIdentifier(name)} '
          'ON ${quoteMySqlIdentifier(tableName)} (${columns.join(',')});',
        );
        break;
      case IndexType.standardIndex:
      case IndexType.none:
        _stack.add(
          'CREATE INDEX ${quoteMySqlIdentifier(name)} ON ${quoteMySqlIdentifier(tableName)} (${columns.join(',')});',
        );
        break;
    }
  }

  @override
  void dropIndex(String name) {
    _stack.add(
      'DROP INDEX IF EXISTS ${quoteMySqlIdentifier(name)} ON ${quoteMySqlIdentifier(tableName)};',
    );
  }

  @override
  void dropPrimaryIndex() {
    _stack.add('DROP INDEX `PRIMARY` ON ${quoteMySqlIdentifier(tableName)};');
  }
}
