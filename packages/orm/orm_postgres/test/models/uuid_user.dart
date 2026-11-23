import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'uuid_user.g.dart';

/// A `Model` whose `id` is a UUID, with posts of an integer `id`.
@serializable
@orm
abstract class UuidUserEntity extends Model {
  @override
  @Column(type: ColumnType('uuid'), indexType: IndexType.primaryKey)
  String? get id;

  String? get name;

  @HasMany(foreignKey: 'author_id')
  List<UuidPostEntity> get posts;
}

@serializable
@orm
abstract class UuidPostEntity extends Model {
  String? get title;

  @BelongsTo(localKey: 'author_id')
  UuidUserEntity? get author;
}
