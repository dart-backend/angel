import 'package:angel3_migration/angel3_migration.dart';

import '../mysql_family.dart';

/// MariaDB SQL query generator
abstract class MariaDbGenerator {
  static const _generator = MySqlFamilyGenerator(maxScale: 38);

  static String columnType(MigrationColumn column) =>
      _generator.columnType(column);

  static String compileColumn(MigrationColumn column) =>
      _generator.compileColumn(column);

  static String? compileIndex(String name, MigrationColumn column) =>
      MySqlFamilyGenerator.compileIndex(name, column);

  static String compileReference(MigrationColumnReference ref) =>
      MySqlFamilyGenerator.compileReference(ref);
}

class MariaDbTable extends MySqlFamilyTable {
  MariaDbTable() : super(MariaDbGenerator._generator);
}

class MariaDbAlterTable extends ModifyingAlterTable {
  MariaDbAlterTable(String tableName)
    : super(
        tableName,
        MariaDbGenerator.compileColumn,
        compileIndex: MariaDbGenerator.compileIndex,
        ifExists: true,
      );
}

class MariaDbIndexes extends MySqlFamilyIndexes {
  MariaDbIndexes(super.tableName) : super(ifExists: true);
}
