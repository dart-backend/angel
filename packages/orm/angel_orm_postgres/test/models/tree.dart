import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'tree.g.dart';

@serializable
@orm
class TreeEntity extends Model {
  @Column(indexType: IndexType.unique, type: ColumnType.smallInt)
  int? rings;

  @hasMany
  List<FruitEntity> fruits = [];
}

@serializable
@orm
class FruitEntity extends Model {
  int? treeId;
  String? commonName;
}
