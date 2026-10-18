import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';

/// The column that `changeColumnType` changes a column to: of [type], with
/// its [length], [precision] and [scale], nullable or not as [isNullable]
/// (nullable if `null`), and with [defaultValue]. It has no index type or
/// reference, so that compiling it adds no index or reference.
MigrationColumn changedColumn(
  ColumnType type, {
  required int length,
  int? precision,
  int? scale,
  bool? isNullable,
  Object? defaultValue,
}) => MigrationColumn(
  type,
  length: length,
  precision: precision,
  scale: scale,
  isNullable: isNullable ?? true,
  defaultValue: defaultValue,
);

/// The `MODIFY` of `changeColumnType` on MySQL and MariaDB, which define the
/// whole column [name] again, as [compileColumn] compiles the
/// [changedColumn], so that it has only the constraints given.
String compileModify(
  String name,
  ColumnType type, {
  required String Function(MigrationColumn column) compileColumn,
  required int length,
  int? precision,
  int? scale,
  bool? isNullable,
  Object? defaultValue,
  bool autoIncrement = false,
}) {
  var column = changedColumn(
    type,
    length: length,
    precision: precision,
    scale: scale,
    isNullable: isNullable,
    defaultValue: defaultValue,
  );
  var sql = 'MODIFY $name ${compileColumn(column)}';
  return autoIncrement ? '$sql AUTO_INCREMENT' : sql;
}
