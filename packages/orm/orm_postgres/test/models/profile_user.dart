import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'profile_user.g.dart';

/// A model with fields of `@serializable` classes that are not ORM models,
/// stored as JSON.
@orm
@serializable
abstract class _ProfileUser extends Model {
  String get name;

  _UserProfile? get profile;

  _UserAddress get address;
}

@serializable
abstract class _UserProfile {
  String get firstName;

  String get lastName;
}

@serializable
abstract class _UserAddress {
  String get city;
}
