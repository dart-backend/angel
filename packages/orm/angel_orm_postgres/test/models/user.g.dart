// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class UserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('users', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('username', length: 255);
      table.varChar('password', length: 255);
      table.varChar('email', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('users', cascade: true);
  }
}

class RoleUserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('role_users', (table) {
      table.declare('role_id', ColumnType('int')).references('roles', 'id');
      table.declare('user_id', ColumnType('int')).references('users', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('role_users');
  }
}

class RoleMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('roles', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('roles', cascade: true);
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class User extends UserEntity {
  User({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.username,
    this.password,
    this.email,
    List<RoleEntity> roles = const [],
  }) : roles = List.unmodifiable(roles);

  /// A unique identifier corresponding to this item.
  @override
  String? id;

  /// The time at which this item was created.
  @override
  DateTime? createdAt;

  /// The last time at which this item was updated.
  @override
  DateTime? updatedAt;

  @override
  String? username;

  @override
  String? password;

  @override
  String? email;

  @override
  List<RoleEntity> roles;

  User copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? username,
    String? password,
    String? email,
    List<RoleEntity>? roles,
  }) {
    return User(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      password: password ?? this.password,
      email: email ?? this.email,
      roles: roles ?? this.roles,
    );
  }

  @override
  bool operator ==(other) {
    return other is UserEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.username == username &&
        other.password == password &&
        other.email == email &&
        ListEquality<RoleEntity>(
          DefaultEquality<RoleEntity>(),
        ).equals(other.roles, roles);
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      username,
      password,
      email,
      roles,
    ]);
  }

  @override
  String toString() {
    return 'User(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, username=$username, password=$password, email=$email, roles=$roles)';
  }

  Map<String, dynamic> toJson() {
    return UserSerializer.toMap(this);
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
class Role extends RoleEntity {
  Role({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name,
    List<UserEntity> users = const [],
  }) : users = List.unmodifiable(users);

  /// A unique identifier corresponding to this item.
  @override
  String? id;

  /// The time at which this item was created.
  @override
  DateTime? createdAt;

  /// The last time at which this item was updated.
  @override
  DateTime? updatedAt;

  @override
  String? name;

  @override
  List<UserEntity> users;

  Role copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    List<UserEntity>? users,
  }) {
    return Role(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      users: users ?? this.users,
    );
  }

  @override
  bool operator ==(other) {
    return other is RoleEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        ListEquality<UserEntity>(
          DefaultEquality<UserEntity>(),
        ).equals(other.users, users);
  }

  @override
  int get hashCode {
    return hashObjects([id, createdAt, updatedAt, name, users]);
  }

  @override
  String toString() {
    return 'Role(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, users=$users)';
  }

  Map<String, dynamic> toJson() {
    return RoleSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

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
      id: map['id'] as String?,
      createdAt: map['created_at'] != null
          ? (map['created_at'] is DateTime
                ? (map['created_at'] as DateTime)
                : DateTime.parse(map['created_at'].toString()))
          : null,
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is DateTime
                ? (map['updated_at'] as DateTime)
                : DateTime.parse(map['updated_at'].toString()))
          : null,
      username: map['username'] as String?,
      password: map['password'] as String?,
      email: map['email'] as String?,
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
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'username': model.username,
      'password': model.password,
      'email': model.email,
      'roles': model.roles.map((m) => RoleSerializer.toMap(m)).toList(),
    };
  }
}

abstract class UserFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    username,
    password,
    email,
    roles,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String username = 'username';

  static const String password = 'password';

  static const String email = 'email';

  static const String roles = 'roles';
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
      id: map['id'] as String?,
      createdAt: map['created_at'] != null
          ? (map['created_at'] is DateTime
                ? (map['created_at'] as DateTime)
                : DateTime.parse(map['created_at'].toString()))
          : null,
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is DateTime
                ? (map['updated_at'] as DateTime)
                : DateTime.parse(map['updated_at'].toString()))
          : null,
      name: map['name'] as String?,
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
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'users': model.users.map((m) => UserSerializer.toMap(m)).toList(),
    };
  }
}

abstract class RoleFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    users,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String users = 'users';
}
