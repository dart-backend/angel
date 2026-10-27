import 'package:angel3_migration/angel3_migration.dart';
import 'package:logging/logging.dart';

import '../mysql_family.dart';

/// MySQL SQL query generator
abstract class MySqlGenerator {
  static const _generator = MySqlFamilyGenerator(maxScale: 30);

  static String columnType(MigrationColumn column) =>
      _generator.columnType(column);

  static String compileColumn(MigrationColumn column) =>
      _generator.compileColumn(column);

  static String? compileIndex(String name, MigrationColumn column) =>
      MySqlFamilyGenerator.compileIndex(name, column);

  static String compileReference(MigrationColumnReference ref) =>
      MySqlFamilyGenerator.compileReference(ref);
}

class MysqlTable extends MySqlFamilyTable {
  final _log = Logger('MysqlTable');

  MysqlTable() : super(MySqlGenerator._generator);

  @override
  void compile(StringBuffer buf, int indent) {
    super.compile(buf, indent);
    _log.fine(buf);
  }
}

class MysqlAlterTable extends ModifyingAlterTable {
  MysqlAlterTable(String tableName)
    : super(
        tableName,
        MySqlGenerator.compileColumn,
        compileIndex: MySqlGenerator.compileIndex,
        ifExists: false,
      );
}

class MysqlIndexes extends MySqlFamilyIndexes {
  MysqlIndexes(super.tableName) : super(ifExists: false);
}
