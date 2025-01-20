import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'quotation.g.dart';

@serializable
@orm
abstract class _Quotation {
  @PrimaryKey(columnType: ColumnType.varChar)
  String? get id;

  String? get name;

  double? get price;
}
