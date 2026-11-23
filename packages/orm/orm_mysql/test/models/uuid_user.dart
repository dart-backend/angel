import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'uuid_user.g.dart';

/// A `Model` whose `id` is a UUID in `CHAR(36)`, as MySQL has no `uuid` type, with posts of an integer `id`.
@serializable
@orm
abstract class UuidUserEntity extends Model {
  @override
  @Column(type: ColumnType.uuid, indexType: IndexType.primaryKey)
  String? get id;

  String? get name;

  @HasMany(foreignKey: 'author_id')
  List<UuidPostEntity> get posts;

  @ManyToMany(UuidUserTagEntity)
  List<UuidTagEntity> get tags;

  @ManyToMany(UuidUserGroupEntity)
  List<UuidGroupEntity> get groups;
}

@serializable
@orm
abstract class UuidPostEntity extends Model {
  String? get title;

  @BelongsTo(localKey: 'author_id')
  UuidUserEntity? get author;
}

/// A tag of an integer `id`, of many users of a UUID.
@serializable
@orm
abstract class UuidTagEntity extends Model {
  String? get name;

  @ManyToMany(UuidUserTagEntity)
  List<UuidUserEntity> get users;
}

/// The pivot of users and tags: a UUID and an integer key. A many-to-many
/// finds its key in the pivot by its class name, `uuid_user_id`, so the
/// field is named after the class.
@serializable
@orm
abstract class UuidUserTagEntity {
  @belongsTo
  UuidUserEntity? get uuidUser;

  @belongsTo
  UuidTagEntity? get uuidTag;
}

/// A group of a UUID, of many users of a UUID.
@serializable
@orm
abstract class UuidGroupEntity extends Model {
  @override
  @Column(type: ColumnType.uuid, indexType: IndexType.primaryKey)
  String? get id;

  String? get name;

  @ManyToMany(UuidUserGroupEntity)
  List<UuidUserEntity> get users;
}

/// The pivot of users and groups: two UUID keys.
@serializable
@orm
abstract class UuidUserGroupEntity {
  @belongsTo
  UuidUserEntity? get uuidUser;

  @belongsTo
  UuidGroupEntity? get uuidGroup;
}
