import '../mysql_family.dart';
import 'table.dart';

/// A MariaDB database schema generator
class MariaDbSchema extends MySqlFamilySchema {
  @override
  MariaDbTable newTable() => MariaDbTable();

  @override
  MariaDbAlterTable newAlterTable(String tableName) =>
      MariaDbAlterTable(tableName);

  @override
  MariaDbIndexes newIndexes(String tableName) => MariaDbIndexes(tableName);
}
