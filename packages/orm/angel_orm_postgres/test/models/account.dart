import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:angel3_migration/angel3_migration.dart';
import 'package:optional/optional.dart';

import 'asset.dart';

part 'account.g.dart';

@serializable
@orm
abstract class AccountEntity extends Model {
  String get description;

  String get name;

  @Column(type: ColumnType.numeric, precision: 17, scale: 3)
  double get price;

  @hasMany
  List<AssetEntity> get assets;
}
