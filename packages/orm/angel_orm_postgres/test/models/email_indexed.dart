import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'email_indexed.g.dart';

// * https://github.com/angel-dart/angel/issues/116

@serializable
@orm
abstract class _Role {
  @PrimaryKey(columnType: ColumnType.varChar)
  String? get role;

  @ManyToMany(_RoleUser)
  List<_User> get users;
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
abstract class _User {
  // @PrimaryKey(columnType: ColumnType.varChar)
  @primaryKey
  String? get email;
  String? get name;
  String? get password;

  @ManyToMany(_RoleUser)
  List<_Role> get roles;
}
