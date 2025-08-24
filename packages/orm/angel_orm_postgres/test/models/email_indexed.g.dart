// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_indexed.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class RoleMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('roles', (table) {
      table.varChar('role', length: 255).primaryKey();
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('roles', cascade: true);
  }
}

class RoleUserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('role_users', (table) {
      table
          .declare('role_role', ColumnType('varchar'))
          .references('roles', 'role');
      table
          .declare('user_email', ColumnType('varchar'))
          .references('users', 'email');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('role_users');
  }
}

class UserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('users', (table) {
      table.varChar('email', length: 255).primaryKey();
      table.varChar('name', length: 255);
      table.varChar('password', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('users', cascade: true);
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Role implements RoleEntity {
  Role({this.role, this.users = const []});

  @override
  String? role;

  @override
  List<UserEntity> users;

  Role copyWith({String? role, List<UserEntity>? users}) {
    return Role(role: role ?? this.role, users: users ?? this.users);
  }

  @override
  bool operator ==(other) {
    return other is RoleEntity &&
        other.role == role &&
        ListEquality<UserEntity>(
          DefaultEquality<UserEntity>(),
        ).equals(other.users, users);
  }

  @override
  int get hashCode {
    return hashObjects([role, users]);
  }

  @override
  String toString() {
    return 'Role(role=$role, users=$users)';
  }

  Map<String, dynamic> toJson() {
    return RoleSerializer.toMap(this);
  }
}

@generatedSerializable
class RoleUser implements RoleUserEntity {
  RoleUser({this.role, this.user});

  @override
  RoleEntity? role;

  @override
  UserEntity? user;

  RoleUser copyWith({RoleEntity? role, UserEntity? user}) {
    return RoleUser(role: role ?? this.role, user: user ?? this.user);
  }

  @override
  bool operator ==(other) {
    return other is RoleUserEntity && other.role == role && other.user == user;
  }

  @override
  int get hashCode {
    return hashObjects([role, user]);
  }

  @override
  String toString() {
    return 'RoleUser(role=$role, user=$user)';
  }

  Map<String, dynamic> toJson() {
    return RoleUserSerializer.toMap(this);
  }
}

@generatedSerializable
class User implements UserEntity {
  User({this.email, this.name, this.password, this.roles = const []});

  @override
  String? email;

  @override
  String? name;

  @override
  String? password;

  @override
  List<RoleEntity> roles;

  User copyWith({
    String? email,
    String? name,
    String? password,
    List<RoleEntity>? roles,
  }) {
    return User(
      email: email ?? this.email,
      name: name ?? this.name,
      password: password ?? this.password,
      roles: roles ?? this.roles,
    );
  }

  @override
  bool operator ==(other) {
    return other is UserEntity &&
        other.email == email &&
        other.name == name &&
        other.password == password &&
        ListEquality<RoleEntity>(
          DefaultEquality<RoleEntity>(),
        ).equals(other.roles, roles);
  }

  @override
  int get hashCode {
    return hashObjects([email, name, password, roles]);
  }

  @override
  String toString() {
    return 'User(email=$email, name=$name, password=$password, roles=$roles)';
  }

  Map<String, dynamic> toJson() {
    return UserSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const RoleSerializer roleSerializer = RoleSerializer();

class RoleEncoder extends Converter<Role, Map> {
  const RoleEncoder();

  @override
  Map convert(Role model) => RoleSerializer.toMap(model);
}

class RoleDecoder extends Converter<Map, Role> {
  const RoleDecoder();

  @override
  Role convert(Map map) => RoleSerializer.fromMap(map);
}

class RoleSerializer extends Codec<Role, Map> {
  const RoleSerializer();

  @override
  RoleEncoder get encoder => const RoleEncoder();

  @override
  RoleDecoder get decoder => const RoleDecoder();

  static Role fromMap(Map map) {
    return Role(
      role: map['role'] as String?,
      users: map['users'] is Iterable
          ? List.unmodifiable(
              ((map['users'] as Iterable).whereType<Map>()).map(
                UserSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  static Map<String, dynamic> toMap(RoleEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'role': model.role,
      'users': model.users.map((m) => UserSerializer.toMap(m)).toList(),
    };
  }
}

abstract class RoleFields {
  static const List<String> allFields = <String>[role, users];

  static const String role = 'role';

  static const String users = 'users';
}

const RoleUserSerializer roleUserSerializer = RoleUserSerializer();

class RoleUserEncoder extends Converter<RoleUser, Map> {
  const RoleUserEncoder();

  @override
  Map convert(RoleUser model) => RoleUserSerializer.toMap(model);
}

class RoleUserDecoder extends Converter<Map, RoleUser> {
  const RoleUserDecoder();

  @override
  RoleUser convert(Map map) => RoleUserSerializer.fromMap(map);
}

class RoleUserSerializer extends Codec<RoleUser, Map> {
  const RoleUserSerializer();

  @override
  RoleUserEncoder get encoder => const RoleUserEncoder();

  @override
  RoleUserDecoder get decoder => const RoleUserDecoder();

  static RoleUser fromMap(Map map) {
    return RoleUser(
      role: map['role'] != null
          ? RoleSerializer.fromMap(map['role'] as Map)
          : null,
      user: map['user'] != null
          ? UserSerializer.fromMap(map['user'] as Map)
          : null,
    );
  }

  static Map<String, dynamic> toMap(RoleUserEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'role': RoleSerializer.toMap(model.role),
      'user': UserSerializer.toMap(model.user),
    };
  }
}

abstract class RoleUserFields {
  static const List<String> allFields = <String>[role, user];

  static const String role = 'role';

  static const String user = 'user';
}

const UserSerializer userSerializer = UserSerializer();

class UserEncoder extends Converter<User, Map> {
  const UserEncoder();

  @override
  Map convert(User model) => UserSerializer.toMap(model);
}

class UserDecoder extends Converter<Map, User> {
  const UserDecoder();

  @override
  User convert(Map map) => UserSerializer.fromMap(map);
}

class UserSerializer extends Codec<User, Map> {
  const UserSerializer();

  @override
  UserEncoder get encoder => const UserEncoder();

  @override
  UserDecoder get decoder => const UserDecoder();

  static User fromMap(Map map) {
    return User(
      email: map['email'] as String?,
      name: map['name'] as String?,
      password: map['password'] as String?,
      roles: map['roles'] is Iterable
          ? List.unmodifiable(
              ((map['roles'] as Iterable).whereType<Map>()).map(
                RoleSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  static Map<String, dynamic> toMap(UserEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'email': model.email,
      'name': model.name,
      'password': model.password,
      'roles': model.roles.map((m) => RoleSerializer.toMap(m)).toList(),
    };
  }
}

abstract class UserFields {
  static const List<String> allFields = <String>[email, name, password, roles];

  static const String email = 'email';

  static const String name = 'name';

  static const String password = 'password';

  static const String roles = 'roles';
}
