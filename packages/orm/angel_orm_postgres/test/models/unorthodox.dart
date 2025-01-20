import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'unorthodox.g.dart';

@serializable
@orm
abstract class _Unorthodox {
  @Column(indexType: IndexType.primaryKey)
  String? get name;
}

@serializable
@orm
abstract class _WeirdJoin {
  @primaryKey
  int get id;

  @BelongsTo(localKey: 'join_name', foreignKey: 'name')
  _Unorthodox? get unorthodox;

  @hasOne
  _Song? get song;

  @HasMany(foreignKey: 'parent')
  List<_Numba> get numbas;

  @ManyToMany(_FooPivot)
  List<_Foo> get foos;
}

@serializable
@orm
abstract class _Song extends Model {
  int? get weirdJoinId;

  String? get title;
}

@serializable
@orm
class _Numba implements Comparable<_Numba> {
  @primaryKey
  int i = -1;

  int? parent;

  @override
  int compareTo(_Numba other) => i.compareTo(other.i);
}

@serializable
@orm
abstract class _Foo {
  @primaryKey
  String? get bar;

  @ManyToMany(_FooPivot)
  List<_WeirdJoin> get weirdJoins;
}

@serializable
@orm
abstract class _FooPivot {
  @belongsTo
  _WeirdJoin? get weirdJoin;

  @belongsTo
  _Foo? get foo;
}
