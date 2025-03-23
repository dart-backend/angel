library;

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'tree.g.dart';

@serializable
@orm
class _Tree extends Model {
  @Column(indexType: IndexType.unique, type: ColumnType.smallInt)
  int? rings;

  @hasMany
  List<_Fruit> fruits = [];
}

@serializable
@orm
class _Fruit extends Model {
  int? treeId;
  String? commonName;
}
