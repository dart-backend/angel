import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'email_indexed.g.dart';

// * https://github.com/angel-dart/angel/issues/116

@serializable
@orm
abstract class RoleEntity {
  @PrimaryKey(columnType: ColumnType.varChar)
  String? get role;

  @ManyToMany(RoleUserEntity)
  List<UserEntity> get users;
}

@serializable
@orm
abstract class RoleUserEntity {
  @belongsTo
  RoleEntity? get role;

  @belongsTo
  UserEntity? get user;
}

@serializable
@orm
abstract class UserEntity {
  // @PrimaryKey(columnType: ColumnType.varChar)
  @primaryKey
  String? get email;
  String? get name;
  String? get password;

  @ManyToMany(RoleUserEntity)
  List<RoleEntity> get roles;
}
