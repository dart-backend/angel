import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'unorthodox.g.dart';

@serializable
@orm
abstract class UnorthodoxEntity {
  @Column(indexType: IndexType.primaryKey)
  String? get name;
}

@serializable
@orm
abstract class WeirdJoinEntity {
  @primaryKey
  int get id;

  @BelongsTo(localKey: 'join_name', foreignKey: 'name')
  UnorthodoxEntity? get unorthodox;

  @hasOne
  SongEntity? get song;

  @HasMany(foreignKey: 'parent')
  List<NumbaEntity> get numbas;

  @ManyToMany(FooPivotEntity)
  List<FooEntity> get foos;
}

@serializable
@orm
abstract class SongEntity extends Model {
  int? get weirdJoinId;

  String? get title;
}

@serializable
@orm
class NumbaEntity implements Comparable<NumbaEntity> {
  //@primaryKey
  //int i = -1;
  int? i;

  int? parent;

  @override
  int compareTo(NumbaEntity other) => i!.compareTo(other.i!);
}

@serializable
@orm
abstract class FooEntity {
  @primaryKey
  String? get bar;

  @ManyToMany(FooPivotEntity)
  List<WeirdJoinEntity> get weirdJoins;
}

@serializable
@orm
abstract class FooPivotEntity {
  @belongsTo
  WeirdJoinEntity? get weirdJoin;

  @belongsTo
  FooEntity? get foo;
}
