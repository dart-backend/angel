import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:optional/optional.dart';

part 'asset.g.dart';

@serializable
@orm
abstract class _Item extends Model {
  String get description;
}

@serializable
@orm
abstract class _Asset extends Model {
  String get description;

  String get name;

  @Column(type: ColumnType.numeric, precision: 17, scale: 3)
  double get price;

  @hasMany
  List<_Item> get items;
}
