import 'dart:collection';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:charcode/ascii.dart';

abstract class MySqlGenerator {
  static String columnType(MigrationColumn column) {
    var str = column.type.name;
    // Map timestamp time to datetime
    if (column.type == ColumnType.timeStamp) {
      str = ColumnType.dateTime.name;
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

      buf.write(' DEFAULT $s');
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

    _columns.forEach((name, column) {
      var col = MySqlGenerator.compileColumn(column);
      if (i++ > 0) buf.writeln(',');

      for (var i = 0; i < indent; i++) {
        buf.write('  ');
      }

      buf.write('$name $col');
    });
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
