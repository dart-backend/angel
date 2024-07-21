library angel3_orm_generator.test.models.user;

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'user.g.dart';

@serializable
@orm
abstract class _User extends Model {
  String? get username;
  String? get password;
  String? get email;

  @ManyToMany(_RoleUser)
  List<_Role> get roles;
}

@serializable
@orm
abstract class _RoleUser {
  @belongsTo
  _Role? get role;

  @belongsTo
  _User? get user;
}

@serializable
@orm
abstract class _Role extends Model {
  String? name;

  @ManyToMany(_RoleUser)
  List<_User> get users;
}
