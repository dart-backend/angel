// GENERATED CODE - DO NOT MODIFY BY HAND

part of angel3_orm_generator.test.models.user;

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
// OrmGenerator
// **************************************************************************

class UserQuery extends Query<User, UserQueryWhere> {
  UserQuery({Query? parent, Set<String>? trampoline}) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UserQueryWhere(this);
    leftJoin(
        '(SELECT role_users.user_id, roles.id, roles.created_at, roles.updated_at, roles.name FROM roles LEFT JOIN role_users ON role_users.role_id=roles.id)',
        'id',
        'user_id',
        additionalFields: const ['id', 'created_at', 'updated_at', 'name'],
        trampoline: trampoline);
  }

  @override
  final UserQueryValues values = UserQueryValues();

  List<String> _selectedFields = [];

  UserQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'users';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
      'username',
      'password',
      'email'
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  UserQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UserQueryWhere? get where {
    return _where;
  }

  @override
  UserQueryWhere newWhereClause() {
    return UserQueryWhere(this);
  }

  Optional<User> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = User(
        id: fields.contains('id') ? row[0].toString() : null,
        createdAt: fields.contains('created_at') ? mapToDateTime(row[1]) : null,
        updatedAt: fields.contains('updated_at') ? mapToDateTime(row[2]) : null,
        username: fields.contains('username') ? (row[3] as String?) : null,
        password: fields.contains('password') ? (row[4] as String?) : null,
        email: fields.contains('email') ? (row[5] as String?) : null);
    if (row.length > 6) {
      var modelOpt = RoleQuery().parseRow(row.skip(6).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(roles: [m]);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<User> deserialize(List row) {
    return parseRow(row);
  }

  @override
  bool canCompile(trampoline) {
    return (!(trampoline.contains('users') &&
        trampoline.contains('role_users')));
  }

  @override
  Future<List<User>> get(QueryExecutor executor) {
    return super.get(executor).then((result) {
      return result.fold<List<User>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                roles: List<_Role>.from(l.roles)..addAll(model.roles));
        }
      });
    });
  }

  @override
  Future<List<User>> update(QueryExecutor executor) {
    return super.update(executor).then((result) {
      return result.fold<List<User>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                roles: List<_Role>.from(l.roles)..addAll(model.roles));
        }
      });
    });
  }

  @override
  Future<List<User>> delete(QueryExecutor executor) {
    return super.delete(executor).then((result) {
      return result.fold<List<User>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                roles: List<_Role>.from(l.roles)..addAll(model.roles));
        }
      });
    });
  }
}

class UserQueryWhere extends QueryWhere {
  UserQueryWhere(UserQuery query)
      : id = NumericSqlExpressionBuilder<int>(query, 'id'),
        createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
        updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
        username = StringSqlExpressionBuilder(query, 'username'),
        password = StringSqlExpressionBuilder(query, 'password'),
        email = StringSqlExpressionBuilder(query, 'email');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder username;

  final StringSqlExpressionBuilder password;

  final StringSqlExpressionBuilder email;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, username, password, email];
  }
}

class UserQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get id {
    return (values['id'] as String?);
  }

  set id(String? value) => values['id'] = value;
  DateTime? get createdAt {
    return (values['created_at'] as DateTime?);
  }

  set createdAt(DateTime? value) => values['created_at'] = value;
  DateTime? get updatedAt {
    return (values['updated_at'] as DateTime?);
  }

  set updatedAt(DateTime? value) => values['updated_at'] = value;
  String? get username {
    return (values['username'] as String?);
  }

  set username(String? value) => values['username'] = value;
  String? get password {
    return (values['password'] as String?);
  }

  set password(String? value) => values['password'] = value;
  String? get email {
    return (values['email'] as String?);
  }

  set email(String? value) => values['email'] = value;
  void copyFrom(User model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    username = model.username;
    password = model.password;
    email = model.email;
  }
}

class RoleUserQuery extends Query<RoleUser, RoleUserQueryWhere> {
  RoleUserQuery({Query? parent, Set<String>? trampoline})
      : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = RoleUserQueryWhere(this);
    leftJoin(_role = RoleQuery(trampoline: trampoline, parent: this), 'role_id',
        'id',
        additionalFields: const ['id', 'created_at', 'updated_at', 'name'],
        trampoline: trampoline);
    leftJoin(_user = UserQuery(trampoline: trampoline, parent: this), 'user_id',
        'id',
        additionalFields: const [
          'id',
          'created_at',
          'updated_at',
          'username',
          'password',
          'email'
        ],
        trampoline: trampoline);
  }

  @override
  final RoleUserQueryValues values = RoleUserQueryValues();

  List<String> _selectedFields = [];

  RoleUserQueryWhere? _where;

  late RoleQuery _role;

  late UserQuery _user;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'role_users';
  }

  @override
  List<String> get fields {
    const _fields = ['role_id', 'user_id'];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  RoleUserQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  RoleUserQueryWhere? get where {
    return _where;
  }

  @override
  RoleUserQueryWhere newWhereClause() {
    return RoleUserQueryWhere(this);
  }

  Optional<RoleUser> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = RoleUser();
    if (row.length > 2) {
      var modelOpt = RoleQuery().parseRow(row.skip(2).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(role: m);
      });
    }
    if (row.length > 6) {
      var modelOpt = UserQuery().parseRow(row.skip(6).take(6).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(user: m);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<RoleUser> deserialize(List row) {
    return parseRow(row);
  }

  RoleQuery get role {
    return _role;
  }

  UserQuery get user {
    return _user;
  }
}

class RoleUserQueryWhere extends QueryWhere {
  RoleUserQueryWhere(RoleUserQuery query)
      : roleId = NumericSqlExpressionBuilder<int>(query, 'role_id'),
        userId = NumericSqlExpressionBuilder<int>(query, 'user_id');

  final NumericSqlExpressionBuilder<int> roleId;

  final NumericSqlExpressionBuilder<int> userId;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [roleId, userId];
  }
}

class RoleUserQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  int get roleId {
    return (values['role_id'] as int);
  }

  set roleId(int value) => values['role_id'] = value;
  int get userId {
    return (values['user_id'] as int);
  }

  set userId(int value) => values['user_id'] = value;
  void copyFrom(RoleUser model) {
    if (model.role != null) {
      values['role_id'] = model.role?.id;
    }
    if (model.user != null) {
      values['user_id'] = model.user?.id;
    }
  }
}

class RoleQuery extends Query<Role, RoleQueryWhere> {
  RoleQuery({Query? parent, Set<String>? trampoline}) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = RoleQueryWhere(this);
    leftJoin(
        '(SELECT role_users.role_id, users.id, users.created_at, users.updated_at, users.username, users.password, users.email FROM users LEFT JOIN role_users ON role_users.user_id=users.id)',
        'id',
        'role_id',
        additionalFields: const [
          'id',
          'created_at',
          'updated_at',
          'username',
          'password',
          'email'
        ],
        trampoline: trampoline);
  }

  @override
  final RoleQueryValues values = RoleQueryValues();

  List<String> _selectedFields = [];

  RoleQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'roles';
  }

  @override
  List<String> get fields {
    const _fields = ['id', 'created_at', 'updated_at', 'name'];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  RoleQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  RoleQueryWhere? get where {
    return _where;
  }

  @override
  RoleQueryWhere newWhereClause() {
    return RoleQueryWhere(this);
  }

  Optional<Role> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Role(
        id: fields.contains('id') ? row[0].toString() : null,
        createdAt: fields.contains('created_at') ? mapToDateTime(row[1]) : null,
        updatedAt: fields.contains('updated_at') ? mapToDateTime(row[2]) : null,
        name: fields.contains('name') ? (row[3] as String?) : null);
    if (row.length > 4) {
      var modelOpt = UserQuery().parseRow(row.skip(4).take(6).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(users: [m]);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<Role> deserialize(List row) {
    return parseRow(row);
  }

  @override
  bool canCompile(trampoline) {
    return (!(trampoline.contains('roles') &&
        trampoline.contains('role_users')));
  }

  @override
  Future<List<Role>> get(QueryExecutor executor) {
    return super.get(executor).then((result) {
      return result.fold<List<Role>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                users: List<_User>.from(l.users)..addAll(model.users));
        }
      });
    });
  }

  @override
  Future<List<Role>> update(QueryExecutor executor) {
    return super.update(executor).then((result) {
      return result.fold<List<Role>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                users: List<_User>.from(l.users)..addAll(model.users));
        }
      });
    });
  }

  @override
  Future<List<Role>> delete(QueryExecutor executor) {
    return super.delete(executor).then((result) {
      return result.fold<List<Role>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
                users: List<_User>.from(l.users)..addAll(model.users));
        }
      });
    });
  }
}

class RoleQueryWhere extends QueryWhere {
  RoleQueryWhere(RoleQuery query)
      : id = NumericSqlExpressionBuilder<int>(query, 'id'),
        createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
        updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
        name = StringSqlExpressionBuilder(query, 'name');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, name];
  }
}

class RoleQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get id {
    return (values['id'] as String?);
  }

  set id(String? value) => values['id'] = value;
  DateTime? get createdAt {
    return (values['created_at'] as DateTime?);
  }

  set createdAt(DateTime? value) => values['created_at'] = value;
  DateTime? get updatedAt {
    return (values['updated_at'] as DateTime?);
  }

  set updatedAt(DateTime? value) => values['updated_at'] = value;
  String? get name {
    return (values['name'] as String?);
  }

  set name(String? value) => values['name'] = value;
  void copyFrom(Role model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class User extends _User {
  User(
      {this.id,
      this.createdAt,
      this.updatedAt,
      this.username,
      this.password,
      this.email,
      List<_Role> roles = const []})
      : roles = List.unmodifiable(roles);

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
  List<_Role> roles;

  User copyWith(
      {String? id,
      DateTime? createdAt,
      DateTime? updatedAt,
      String? username,
      String? password,
      String? email,
      List<_Role>? roles}) {
    return User(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        username: username ?? this.username,
        password: password ?? this.password,
        email: email ?? this.email,
        roles: roles ?? this.roles);
  }

  @override
  bool operator ==(other) {
    return other is _User &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.username == username &&
        other.password == password &&
        other.email == email &&
        ListEquality<_Role>(DefaultEquality<_Role>())
            .equals(other.roles, roles);
  }

  @override
  int get hashCode {
    return hashObjects(
        [id, createdAt, updatedAt, username, password, email, roles]);
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
class RoleUser implements _RoleUser {
  RoleUser({this.role, this.user});

  @override
  _Role? role;

  @override
  _User? user;

  RoleUser copyWith({_Role? role, _User? user}) {
    return RoleUser(role: role ?? this.role, user: user ?? this.user);
  }

  @override
  bool operator ==(other) {
    return other is _RoleUser && other.role == role && other.user == user;
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
class Role extends _Role {
  Role(
      {this.id,
      this.createdAt,
      this.updatedAt,
      this.name,
      List<_User> users = const []})
      : users = List.unmodifiable(users);

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
  List<_User> users;

  Role copyWith(
      {String? id,
      DateTime? createdAt,
      DateTime? updatedAt,
      String? name,
      List<_User>? users}) {
    return Role(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        name: name ?? this.name,
        users: users ?? this.users);
  }

  @override
  bool operator ==(other) {
    return other is _Role &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        ListEquality<_User>(DefaultEquality<_User>())
            .equals(other.users, users);
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
            ? List.unmodifiable(((map['roles'] as Iterable).whereType<Map>())
                .map(RoleSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(_User? model) {
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
      'roles': model.roles.map((m) => RoleSerializer.toMap(m)).toList()
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
    roles
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
            : null);
  }

  static Map<String, dynamic> toMap(_RoleUser? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'role': RoleSerializer.toMap(model.role),
      'user': UserSerializer.toMap(model.user)
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
            ? List.unmodifiable(((map['users'] as Iterable).whereType<Map>())
                .map(UserSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(_Role? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'users': model.users.map((m) => UserSerializer.toMap(m)).toList()
    };
  }
}

abstract class RoleFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    users
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String users = 'users';
}
