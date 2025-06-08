import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'user.g.dart';

@serializable
@orm
abstract class UserEntity extends Model {
  String? get username;
  String? get password;
  String? get email;

  @ManyToMany(RoleUserEntity)
  List<RoleEntity> get roles;
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
abstract class RoleEntity extends Model {
  String? name;

  @ManyToMany(RoleUserEntity)
  List<UserEntity> get users;
}
