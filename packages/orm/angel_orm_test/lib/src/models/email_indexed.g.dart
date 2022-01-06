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
// OrmGenerator
// **************************************************************************

class RoleQuery extends Query<Role, RoleQueryWhere> {
  RoleQuery({Query? parent, Set<String>? trampoline}) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = RoleQueryWhere(this);
    leftJoin(
        '(SELECT role_users.role_role, users.email, users.name, users.password FROM users LEFT JOIN role_users ON role_users.user_email=users.email)',
        'role',
        'role_role',
        additionalFields: const ['email', 'name', 'password'],
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
    const _fields = ['role'];
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
    var model =
        Role(role: fields.contains('role') ? (row[0] as String?) : null);
    if (row.length > 1) {
      var modelOpt = UserQuery().parseRow(row.skip(1).take(3).toList());
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
        var idx = out.indexWhere((m) => m.role == model.role);

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
        var idx = out.indexWhere((m) => m.role == model.role);

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
        var idx = out.indexWhere((m) => m.role == model.role);

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
      : role = StringSqlExpressionBuilder(query, 'role');

  final StringSqlExpressionBuilder role;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [role];
  }
}

class RoleQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get role {
    return (values['role'] as String?);
  }

  set role(String? value) => values['role'] = value;
  void copyFrom(Role model) {
    role = model.role;
  }
}

class RoleUserQuery extends Query<RoleUser, RoleUserQueryWhere> {
  RoleUserQuery({Query? parent, Set<String>? trampoline})
      : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = RoleUserQueryWhere(this);
    leftJoin(_role = RoleQuery(trampoline: trampoline, parent: this),
        'role_role', 'role',
        additionalFields: const ['role'], trampoline: trampoline);
    leftJoin(_user = UserQuery(trampoline: trampoline, parent: this),
        'user_email', 'email',
        additionalFields: const ['email', 'name', 'password'],
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
    const _fields = ['role_role', 'user_email'];
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
      var modelOpt = RoleQuery().parseRow(row.skip(2).take(1).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(role: m);
      });
    }
    if (row.length > 3) {
      var modelOpt = UserQuery().parseRow(row.skip(3).take(3).toList());
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
      : roleRole = StringSqlExpressionBuilder(query, 'role_role'),
        userEmail = StringSqlExpressionBuilder(query, 'user_email');

  final StringSqlExpressionBuilder roleRole;

  final StringSqlExpressionBuilder userEmail;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [roleRole, userEmail];
  }
}

class RoleUserQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get roleRole {
    return (values['role_role'] as String?);
  }

  set roleRole(String? value) => values['role_role'] = value;
  String? get userEmail {
    return (values['user_email'] as String?);
  }

  set userEmail(String? value) => values['user_email'] = value;
  void copyFrom(RoleUser model) {
    if (model.role != null) {
      values['role_role'] = model.role?.role;
    }
    if (model.user != null) {
      values['user_email'] = model.user?.email;
    }
  }
}

class UserQuery extends Query<User, UserQueryWhere> {
  UserQuery({Query? parent, Set<String>? trampoline}) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UserQueryWhere(this);
    leftJoin(
        '(SELECT role_users.user_email, roles.role FROM roles LEFT JOIN role_users ON role_users.role_role=roles.role)',
        'email',
        'user_email',
        additionalFields: const ['role'],
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
    const _fields = ['email', 'name', 'password'];
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
        email: fields.contains('email') ? (row[0] as String?) : null,
        name: fields.contains('name') ? (row[1] as String?) : null,
        password: fields.contains('password') ? (row[2] as String?) : null);
    if (row.length > 3) {
      var modelOpt = RoleQuery().parseRow(row.skip(3).take(1).toList());
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
        var idx = out.indexWhere((m) => m.email == model.email);

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
        var idx = out.indexWhere((m) => m.email == model.email);

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
        var idx = out.indexWhere((m) => m.email == model.email);

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
      : email = StringSqlExpressionBuilder(query, 'email'),
        name = StringSqlExpressionBuilder(query, 'name'),
        password = StringSqlExpressionBuilder(query, 'password');

  final StringSqlExpressionBuilder email;

  final StringSqlExpressionBuilder name;

  final StringSqlExpressionBuilder password;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [email, name, password];
  }
}

class UserQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get email {
    return (values['email'] as String?);
  }

  set email(String? value) => values['email'] = value;
  String? get name {
    return (values['name'] as String?);
  }

  set name(String? value) => values['name'] = value;
  String? get password {
    return (values['password'] as String?);
  }

  set password(String? value) => values['password'] = value;
  void copyFrom(User model) {
    email = model.email;
    name = model.name;
    password = model.password;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Role implements _Role {
  Role({this.role, this.users = const []});

  @override
  String? role;

  @override
  List<_User> users;

  Role copyWith({String? role, List<_User>? users}) {
    return Role(role: role ?? this.role, users: users ?? this.users);
  }

  @override
  bool operator ==(other) {
    return other is _Role &&
        other.role == role &&
        ListEquality<_User>(DefaultEquality<_User>())
            .equals(other.users, users);
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
class User implements _User {
  User({this.email, this.name, this.password, this.roles = const []});

  @override
  String? email;

  @override
  String? name;

  @override
  String? password;

  @override
  List<_Role> roles;

  User copyWith(
      {String? email, String? name, String? password, List<_Role>? roles}) {
    return User(
        email: email ?? this.email,
        name: name ?? this.name,
        password: password ?? this.password,
        roles: roles ?? this.roles);
  }

  @override
  bool operator ==(other) {
    return other is _User &&
        other.email == email &&
        other.name == name &&
        other.password == password &&
        ListEquality<_Role>(DefaultEquality<_Role>())
            .equals(other.roles, roles);
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
            ? List.unmodifiable(((map['users'] as Iterable).whereType<Map>())
                .map(UserSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(_Role? model) {
    if (model == null) {
      return {};
    }
    return {
      'role': model.role,
      'users': model.users.map((m) => UserSerializer.toMap(m)).toList()
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
            : null);
  }

  static Map<String, dynamic> toMap(_RoleUser? model) {
    if (model == null) {
      return {};
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
            ? List.unmodifiable(((map['roles'] as Iterable).whereType<Map>())
                .map(RoleSerializer.fromMap))
            : []);
  }

  static Map<String, dynamic> toMap(_User? model) {
    if (model == null) {
      return {};
    }
    return {
      'email': model.email,
      'name': model.name,
      'password': model.password,
      'roles': model.roles.map((m) => RoleSerializer.toMap(m)).toList()
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
