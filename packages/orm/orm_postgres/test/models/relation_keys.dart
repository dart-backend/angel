import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'relation_keys.g.dart';

/// A model with a table name of its own.
@serializable
@Orm(tableName: 'identities')
abstract class UserIdentityEntity extends Model {
  String? get handle;
}

@serializable
@orm
abstract class LoginEntity extends Model {
  String? get name;

  /// Its column, `userIdentityId`, has `Id` inside its name too.
  @belongsTo
  UserIdentityEntity? get userIdentity;

  /// A relation with an explicit table.
  @BelongsTo(foreignTable: 'identities')
  UserIdentityEntity? get backupIdentity;

  /// A many-to-many through a class with a table name of its own.
  @ManyToMany(LoginGrantEntity)
  List<GrantEntity> get grants;
}

@serializable
@Orm(tableName: 'login_grant_links')
abstract class LoginGrantEntity {
  @belongsTo
  LoginEntity? get login;

  @belongsTo
  GrantEntity? get grant;
}

@serializable
@orm
abstract class GrantEntity extends Model {
  String? name;

  @ManyToMany(LoginGrantEntity)
  List<LoginEntity> get logins;
}
