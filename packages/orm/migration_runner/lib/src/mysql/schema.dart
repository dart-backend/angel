import '../mysql_family.dart';
import 'table.dart';

/// A MySQL database schema generator
class MySqlSchema extends MySqlFamilySchema {
  @override
  MysqlTable newTable() => MysqlTable();

  @override
  MysqlAlterTable newAlterTable(String tableName) => MysqlAlterTable(tableName);

  @override
  MysqlIndexes newIndexes(String tableName) => MysqlIndexes(tableName);
}
