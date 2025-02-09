import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:charcode/ascii.dart';

/// MySQL SQL query generator
abstract class MySqlGenerator {
  static final List<String> _charColumnType = [
    ColumnType.varChar.name,
    ColumnType.char.name
  ];

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

    // Map serial to int
    if (str.toLowerCase() == ColumnType.serial.name) {
      return ColumnType.int.name;
    }

    // Map timestamp time to datetime
    if (column.type == ColumnType.timeStamp) {
      str = ColumnType.dateTime.name;
    }

    if (_charColumnType.contains(str)) {
      if (column.type.hasLength) {
        return '$str(${column.length})';
      } else {
        return '$str(255)';
      }
    }

    if (column.type.hasLength) {
      return '$str(${column.length})';
    } else {
      return str;
    }
  }

  static String compileColumn(MigrationColumn column) {
    var buf = StringBuffer(columnType(column));

    if (!column.isNullable) {
      buf.write(' NOT NULL');
    }

    // Default value
    if (column.defaultValue != null) {
      String s;
      var value = column.defaultValue;
      if (value is RawSql) {
        s = value.value;
      } else if (value is String) {
        var b = StringBuffer();
        for (var ch in value.codeUnits) {
          if (ch == $single_quote) {
            b.write("\\'");
          } else {
            b.writeCharCode(ch);
          }
        }
        s = b.toString();
      } else {
        s = value.toString();
      }

      if (column.type == ColumnType.varChar) {
        buf.write(' DEFAULT \'$s\'');
      } else {
        buf.write(' DEFAULT $s');
      }
    }

    if (column.indexType == IndexType.primaryKey) {
      buf.write(' PRIMARY KEY');

      // For int based primary key, apply NOT NULL
      // and AUTO_INCREMENT
      if (column.type == ColumnType.int || column.type == ColumnType.serial) {
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
      return ' INDEX(`$name`)';
    } else if (column.indexType == IndexType.unique) {
      return ' UNIQUE KEY unique_$name (`$name`)';
    }

    return null;
  }

  static String compileReference(MigrationColumnReference ref) {
    var buf = StringBuffer('REFERENCES ${ref.foreignTable}(${ref.foreignKey})');
    if (ref.behavior != null) buf.write(' ${ref.behavior!}');
    return buf.toString();
  }
}

class MysqlTable extends Table {
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
    List indexBuf = [];

    _columns.forEach((name, column) {
      var col = MySqlGenerator.compileColumn(column);
      if (i++ > 0) buf.writeln(',');

      for (var i = 0; i < indent; i++) {
        buf.write('  ');
      }

      buf.write('$name $col');

      var index = MySqlGenerator.compileIndex(name, column);
      if (index != null) indexBuf.add(index);
    });

    if (indexBuf.isNotEmpty) {
      for (var i = 0; i < indexBuf.length; i++) {
        buf.write(',\n${indexBuf[i]}');
      }
    }
  }
}

class MysqlAlterTable extends Table implements MutableTable {
  final Map<String, MigrationColumn> _columns = {};
  final String tableName;
  final Queue<String> _stack = Queue<String>();

  MysqlAlterTable(this.tableName);

  void compile(StringBuffer buf, int indent) {
    var i = 0;

    while (_stack.isNotEmpty) {
      var str = _stack.removeFirst();

      if (i++ > 0) buf.writeln(',');

      for (var i = 0; i < indent; i++) {
        buf.write('  ');
      }

      buf.write(str);
    }

    if (i > 0) buf.writeln(';');

    i = 0;
    _columns.forEach((name, column) {
      var col = MySqlGenerator.compileColumn(column);
      if (i++ > 0) buf.writeln(',');

      for (var i = 0; i < indent; i++) {
        buf.write('  ');
      }

      buf.write('ADD COLUMN $name $col');
    });
  }

  @override
  MigrationColumn declareColumn(String name, Column column) {
    if (_columns.containsKey(name)) {
      throw StateError('Cannot redeclare column $name.');
    }
    var col = MigrationColumn.from(column);
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
  void changeColumnType(String name, ColumnType type, {int length = 256}) {
    _stack.add(
        'MODIFY $name ${MySqlGenerator.columnType(MigrationColumn(type, length: length))}');
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
    String indexType = '';

    switch (type) {
      case IndexType.primaryKey:
        indexType = 'PRIMARY KEY';
        break;
      case IndexType.unique:
        indexType = 'UNIQUE INDEX `$name`';
        break;
      case IndexType.standardIndex:
      case IndexType.none:
        indexType = 'INDEX `$name`';
        break;
    }

    // mask the column names, is more safety
    columns.map((column) => '`$column`');

    _stack.add('ADD $indexType (${columns.join(',')})');
  }

  @override
  void dropIndex(String name) {
    _stack.add('DROP INDEX `$name`');
  }

  @override
  void dropPrimaryIndex() {
    _stack.add('DROP PRIMARY KEY');
  }
}

class MysqlIndexes implements MutableIndexes {
  final String tableName;
  final Queue<String> _stack = Queue<String>();

  MysqlIndexes(this.tableName);

  void compile(StringBuffer buf) {
    while (_stack.isNotEmpty) {
      buf.writeln(_stack.removeFirst());
    }
  }

  @override
  void addIndex(String name, List<String> columns, IndexType type) {
    // mask the column names, is more safety
    columns.map((column) => '`$column`');

    switch (type) {
      case IndexType.primaryKey:
        _stack.add(
          'ALTER TABLE `$tableName` ADD PRIMARY KEY (${columns.join(',')});',
        );
        break;
      case IndexType.unique:
        _stack.add(
          'CREATE UNIQUE INDEX `$name` ON `$tableName` (${columns.join(',')});',
        );
        break;
      //case IndexType.standardIndex:
      //case IndexType.none:
      default:
        _stack.add(
          'CREATE INDEX `$name` ON `$tableName` (${columns.join(',')});',
        );
        break;
    }
  }

  @override
  void dropIndex(String name) {
    _stack.add('DROP INDEX `$name` ON `$tableName`;');
  }

  @override
  void dropPrimaryIndex() {
    _stack.add('DROP INDEX `PRIMARY` ON `$tableName`;');
  }
}
