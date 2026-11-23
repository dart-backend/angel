import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'uuid_user.g.dart';

/// A `Model` whose `id` is a UUID, which is given on each insert.
@serializable
@orm
abstract class UuidUserEntity extends Model {
  @override
  @Column(type: ColumnType.uuid, indexType: IndexType.primaryKey)
  String? get id;

  String? get name;
}
