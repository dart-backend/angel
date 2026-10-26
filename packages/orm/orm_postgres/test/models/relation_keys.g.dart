// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relation_keys.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class UserIdentityMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('identities', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('handle', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('identities');
  }
}

class LoginMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('logins', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
      table
          .declare('user_identity_id', ColumnType.int)
          .references('identities', 'id');
      table
          .declare('backup_identity_id', ColumnType.int)
          .references('identities', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('logins', cascade: true);
  }
}

class LoginGrantMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('login_grant_links', (table) {
      table.declare('login_id', ColumnType.int).references('logins', 'id');
      table.declare('grant_id', ColumnType.int).references('grants', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('login_grant_links');
  }
}

class GrantMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('grants', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('grants', cascade: true);
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class UserIdentityQuery extends Query<UserIdentity, UserIdentityQueryWhere> {
  UserIdentityQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UserIdentityQueryWhere(this);
  }

  @override
  final UserIdentityQueryValues values = UserIdentityQueryValues();

  List<String> _selectedFields = [];

  UserIdentityQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'identities';
  }

  @override
  List<String> get fields {
    const localFields = ['id', 'created_at', 'updated_at', 'handle'];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  UserIdentityQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UserIdentityQueryWhere? get where {
    return _where;
  }

  @override
  UserIdentityQueryWhere newWhereClause() {
    return UserIdentityQueryWhere(this);
  }

  Optional<UserIdentity> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UserIdentity(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[1])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[2])
          : null,
      handle: fields.contains('handle') ? (row[3] as String?) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<UserIdentity> deserialize(List row) {
    return parseRow(row);
  }
}

class UserIdentityQueryWhere extends QueryWhere {
  UserIdentityQueryWhere(UserIdentityQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      handle = StringSqlExpressionBuilder(query, 'handle');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder handle;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, handle];
  }
}

class UserIdentityQueryValues extends MapQueryValues {
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

  String? get handle {
    return (values['handle'] as String?);
  }

  set handle(String? value) => values['handle'] = value;

  void copyFrom(UserIdentity model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    handle = model.handle;
  }
}

class LoginQuery extends Query<Login, LoginQueryWhere> {
  LoginQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = LoginQueryWhere(this);
    leftJoin(
      _userIdentity = UserIdentityQuery(trampoline: trampoline, parent: this),
      'user_identity_id',
      'id',
      additionalFields: const ['id', 'created_at', 'updated_at', 'handle'],
      trampoline: trampoline,
    );
    leftJoin(
      _backupIdentity = UserIdentityQuery(trampoline: trampoline, parent: this),
      'backup_identity_id',
      'id',
      additionalFields: const ['id', 'created_at', 'updated_at', 'handle'],
      trampoline: trampoline,
    );
    leftJoin(
      '(SELECT login_grant_links.login_id, grants.id, grants.created_at, grants.updated_at, grants.name FROM grants LEFT JOIN login_grant_links ON login_grant_links.grant_id=grants.id)',
      'id',
      'login_id',
      additionalFields: const ['id', 'created_at', 'updated_at', 'name'],
      trampoline: trampoline,
    );
  }

  @override
  final LoginQueryValues values = LoginQueryValues();

  List<String> _selectedFields = [];

  LoginQueryWhere? _where;

  late UserIdentityQuery _userIdentity;

  late UserIdentityQuery _backupIdentity;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'logins';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'name',
      'user_identity_id',
      'backup_identity_id',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  LoginQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  LoginQueryWhere? get where {
    return _where;
  }

  @override
  LoginQueryWhere newWhereClause() {
    return LoginQueryWhere(this);
  }

  Optional<Login> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Login(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[1])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[2])
          : null,
      name: fields.contains('name') ? (row[3] as String?) : null,
    );
    if (row.length > 6) {
      var modelOpt = UserIdentityQuery().parseRow(row.skip(6).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(userIdentity: m);
      });
    }
    if (row.length > 10) {
      var modelOpt = UserIdentityQuery().parseRow(
        row.skip(10).take(4).toList(),
      );
      modelOpt.ifPresent((m) {
        model = model.copyWith(backupIdentity: m);
      });
    }
    if (row.length > 14) {
      var modelOpt = GrantQuery().parseRow(row.skip(14).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(grants: [m]);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<Login> deserialize(List row) {
    return parseRow(row);
  }

  UserIdentityQuery get userIdentity {
    return _userIdentity;
  }

  UserIdentityQuery get backupIdentity {
    return _backupIdentity;
  }

  @override
  bool canCompile(trampoline) {
    return (!(trampoline.contains('logins') &&
        trampoline.contains('login_grant_links')));
  }

  @override
  Future<List<Login>> get(QueryExecutor executor) {
    return super.get(executor).then((result) {
      return result.fold<List<Login>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
              grants: List<GrantEntity>.from(l.grants)
                ..addAll(
                  model.grants.where((c) => !l.grants.any((e) => e.id == c.id)),
                ),
            );
        }
      });
    });
  }

  @override
  Future<List<Login>> update(QueryExecutor executor) {
    return super.update(executor).then((result) {
      return result.fold<List<Login>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
              grants: List<GrantEntity>.from(l.grants)
                ..addAll(
                  model.grants.where((c) => !l.grants.any((e) => e.id == c.id)),
                ),
            );
        }
      });
    });
  }

  @override
  Future<List<Login>> delete(QueryExecutor executor) {
    return super.delete(executor).then((result) {
      return result.fold<List<Login>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
              grants: List<GrantEntity>.from(l.grants)
                ..addAll(
                  model.grants.where((c) => !l.grants.any((e) => e.id == c.id)),
                ),
            );
        }
      });
    });
  }
}

class LoginQueryWhere extends QueryWhere {
  LoginQueryWhere(LoginQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      name = StringSqlExpressionBuilder(query, 'name'),
      userIdentityId = NumericSqlExpressionBuilder<int>(
        query,
        'user_identity_id',
      ),
      backupIdentityId = NumericSqlExpressionBuilder<int>(
        query,
        'backup_identity_id',
      );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  final NumericSqlExpressionBuilder<int> userIdentityId;

  final NumericSqlExpressionBuilder<int> backupIdentityId;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, name, userIdentityId, backupIdentityId];
  }
}

class LoginQueryValues extends MapQueryValues {
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

  int? get userIdentityId {
    return (values['user_identity_id'] as int?);
  }

  set userIdentityId(int? value) => values['user_identity_id'] = value;

  int? get backupIdentityId {
    return (values['backup_identity_id'] as int?);
  }

  set backupIdentityId(int? value) => values['backup_identity_id'] = value;

  void copyFrom(Login model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
    if (model.userIdentity?.id != null) {
      values['user_identity_id'] = int.parse(model.userIdentity!.id!);
    }
    if (model.backupIdentity?.id != null) {
      values['backup_identity_id'] = int.parse(model.backupIdentity!.id!);
    }
  }
}

class LoginGrantQuery extends Query<LoginGrant, LoginGrantQueryWhere> {
  LoginGrantQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = LoginGrantQueryWhere(this);
    leftJoin(
      _login = LoginQuery(trampoline: trampoline, parent: this),
      'login_id',
      'id',
      additionalFields: const [
        'id',
        'created_at',
        'updated_at',
        'name',
        'user_identity_id',
        'backup_identity_id',
      ],
      trampoline: trampoline,
    );
    leftJoin(
      _grant = GrantQuery(trampoline: trampoline, parent: this),
      'grant_id',
      'id',
      additionalFields: const ['id', 'created_at', 'updated_at', 'name'],
      trampoline: trampoline,
    );
  }

  @override
  final LoginGrantQueryValues values = LoginGrantQueryValues();

  List<String> _selectedFields = [];

  LoginGrantQueryWhere? _where;

  late LoginQuery _login;

  late GrantQuery _grant;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'login_grant_links';
  }

  @override
  List<String> get fields {
    const localFields = ['login_id', 'grant_id'];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  LoginGrantQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  LoginGrantQueryWhere? get where {
    return _where;
  }

  @override
  LoginGrantQueryWhere newWhereClause() {
    return LoginGrantQueryWhere(this);
  }

  Optional<LoginGrant> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = LoginGrant();
    if (row.length > 2) {
      var modelOpt = LoginQuery().parseRow(row.skip(2).take(6).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(login: m);
      });
    }
    if (row.length > 8) {
      var modelOpt = GrantQuery().parseRow(row.skip(8).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(grant: m);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<LoginGrant> deserialize(List row) {
    return parseRow(row);
  }

  LoginQuery get login {
    return _login;
  }

  GrantQuery get grant {
    return _grant;
  }
}

class LoginGrantQueryWhere extends QueryWhere {
  LoginGrantQueryWhere(LoginGrantQuery query)
    : loginId = NumericSqlExpressionBuilder<int>(query, 'login_id'),
      grantId = NumericSqlExpressionBuilder<int>(query, 'grant_id');

  final NumericSqlExpressionBuilder<int> loginId;

  final NumericSqlExpressionBuilder<int> grantId;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [loginId, grantId];
  }
}

class LoginGrantQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  int? get loginId {
    return (values['login_id'] as int?);
  }

  set loginId(int? value) => values['login_id'] = value;

  int? get grantId {
    return (values['grant_id'] as int?);
  }

  set grantId(int? value) => values['grant_id'] = value;

  void copyFrom(LoginGrant model) {
    if (model.login?.id != null) {
      values['login_id'] = int.parse(model.login!.id!);
    }
    if (model.grant?.id != null) {
      values['grant_id'] = int.parse(model.grant!.id!);
    }
  }
}

class GrantQuery extends Query<Grant, GrantQueryWhere> {
  GrantQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = GrantQueryWhere(this);
    leftJoin(
      '(SELECT login_grant_links.grant_id, logins.id, logins.created_at, logins.updated_at, logins.name, logins.user_identity_id, logins.backup_identity_id FROM logins LEFT JOIN login_grant_links ON login_grant_links.login_id=logins.id)',
      'id',
      'grant_id',
      additionalFields: const [
        'id',
        'created_at',
        'updated_at',
        'name',
        'user_identity_id',
        'backup_identity_id',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final GrantQueryValues values = GrantQueryValues();

  List<String> _selectedFields = [];

  GrantQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'grants';
  }

  @override
  List<String> get fields {
    const localFields = ['id', 'created_at', 'updated_at', 'name'];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  GrantQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  GrantQueryWhere? get where {
    return _where;
  }

  @override
  GrantQueryWhere newWhereClause() {
    return GrantQueryWhere(this);
  }

  Optional<Grant> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Grant(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[1])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[2])
          : null,
      name: fields.contains('name') ? (row[3] as String?) : null,
    );
    if (row.length > 4) {
      var modelOpt = LoginQuery().parseRow(row.skip(4).take(6).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(logins: [m]);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<Grant> deserialize(List row) {
    return parseRow(row);
  }

  @override
  bool canCompile(trampoline) {
    return (!(trampoline.contains('grants') &&
        trampoline.contains('login_grant_links')));
  }

  @override
  Future<List<Grant>> get(QueryExecutor executor) {
    return super.get(executor).then((result) {
      return result.fold<List<Grant>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
              logins: List<LoginEntity>.from(l.logins)
                ..addAll(
                  model.logins.where((c) => !l.logins.any((e) => e.id == c.id)),
                ),
            );
        }
      });
    });
  }

  @override
  Future<List<Grant>> update(QueryExecutor executor) {
    return super.update(executor).then((result) {
      return result.fold<List<Grant>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
              logins: List<LoginEntity>.from(l.logins)
                ..addAll(
                  model.logins.where((c) => !l.logins.any((e) => e.id == c.id)),
                ),
            );
        }
      });
    });
  }

  @override
  Future<List<Grant>> delete(QueryExecutor executor) {
    return super.delete(executor).then((result) {
      return result.fold<List<Grant>>([], (out, model) {
        var idx = out.indexWhere((m) => m.id == model.id);

        if (idx == -1) {
          return out..add(model);
        } else {
          var l = out[idx];
          return out
            ..[idx] = l.copyWith(
              logins: List<LoginEntity>.from(l.logins)
                ..addAll(
                  model.logins.where((c) => !l.logins.any((e) => e.id == c.id)),
                ),
            );
        }
      });
    });
  }
}

class GrantQueryWhere extends QueryWhere {
  GrantQueryWhere(GrantQuery query)
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

class GrantQueryValues extends MapQueryValues {
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

  void copyFrom(Grant model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class UserIdentity extends UserIdentityEntity {
  UserIdentity({this.id, this.createdAt, this.updatedAt, this.handle});

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
  String? handle;

  UserIdentity copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? handle,
  }) {
    return UserIdentity(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      handle: handle ?? this.handle,
    );
  }

  @override
  bool operator ==(other) {
    return other is UserIdentityEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.handle == handle;
  }

  @override
  int get hashCode {
    return Object.hashAll([id, createdAt, updatedAt, handle]);
  }

  @override
  String toString() {
    return 'UserIdentity(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, handle=$handle)';
  }

  Map<String, dynamic> toJson() {
    return UserIdentitySerializer.toMap(this);
  }
}

@generatedSerializable
class Login extends LoginEntity {
  Login({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name,
    this.userIdentity,
    this.backupIdentity,
    List<GrantEntity> grants = const [],
  }) : grants = List.unmodifiable(grants);

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

  /// Its column, `userIdentityId`, has `Id` inside its name too.
  @override
  UserIdentityEntity? userIdentity;

  /// A relation with an explicit table.
  @override
  UserIdentityEntity? backupIdentity;

  /// A many-to-many through a class with a table name of its own.
  @override
  List<GrantEntity> grants;

  Login copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    UserIdentityEntity? userIdentity,
    UserIdentityEntity? backupIdentity,
    List<GrantEntity>? grants,
  }) {
    return Login(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      userIdentity: userIdentity ?? this.userIdentity,
      backupIdentity: backupIdentity ?? this.backupIdentity,
      grants: grants ?? this.grants,
    );
  }

  @override
  bool operator ==(other) {
    return other is LoginEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        other.userIdentity == userIdentity &&
        other.backupIdentity == backupIdentity &&
        ListEquality<GrantEntity>(DefaultEquality<GrantEntity>())
            .equals(other.grants, grants);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      createdAt,
      updatedAt,
      name,
      userIdentity,
      backupIdentity,
      grants.length,
    ]);
  }

  @override
  String toString() {
    return 'Login(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, userIdentity=$userIdentity, backupIdentity=$backupIdentity, grants=$grants)';
  }

  Map<String, dynamic> toJson() {
    return LoginSerializer.toMap(this);
  }
}

@generatedSerializable
class LoginGrant implements LoginGrantEntity {
  LoginGrant({this.login, this.grant});

  @override
  LoginEntity? login;

  @override
  GrantEntity? grant;

  LoginGrant copyWith({LoginEntity? login, GrantEntity? grant}) {
    return LoginGrant(login: login ?? this.login, grant: grant ?? this.grant);
  }

  @override
  bool operator ==(other) {
    return other is LoginGrantEntity &&
        other.login == login &&
        other.grant == grant;
  }

  @override
  int get hashCode {
    return Object.hashAll([login, grant]);
  }

  @override
  String toString() {
    return 'LoginGrant(login=$login, grant=$grant)';
  }

  Map<String, dynamic> toJson() {
    return LoginGrantSerializer.toMap(this);
  }
}

@generatedSerializable
class Grant extends GrantEntity {
  Grant({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name,
    List<LoginEntity> logins = const [],
  }) : logins = List.unmodifiable(logins);

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
  List<LoginEntity> logins;

  Grant copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    List<LoginEntity>? logins,
  }) {
    return Grant(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      logins: logins ?? this.logins,
    );
  }

  @override
  bool operator ==(other) {
    return other is GrantEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        ListEquality<LoginEntity>(DefaultEquality<LoginEntity>())
            .equals(other.logins, logins);
  }

  @override
  int get hashCode {
    return Object.hashAll([id, createdAt, updatedAt, name, logins.length]);
  }

  @override
  String toString() {
    return 'Grant(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, logins=$logins)';
  }

  Map<String, dynamic> toJson() {
    return GrantSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const UserIdentitySerializer userIdentitySerializer = UserIdentitySerializer();

class UserIdentityEncoder extends Converter<UserIdentity, Map> {
  const UserIdentityEncoder();

  @override
  Map convert(UserIdentity model) => UserIdentitySerializer.toMap(model);
}

class UserIdentityDecoder extends Converter<Map, UserIdentity> {
  const UserIdentityDecoder();

  @override
  UserIdentity convert(Map map) => UserIdentitySerializer.fromMap(map);
}

class UserIdentitySerializer extends Codec<UserIdentity, Map> {
  const UserIdentitySerializer();

  @override
  UserIdentityEncoder get encoder => const UserIdentityEncoder();

  @override
  UserIdentityDecoder get decoder => const UserIdentityDecoder();

  static UserIdentity fromMap(Map map) {
    return UserIdentity(
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
      handle: map['handle'] as String?,
    );
  }

  static Map<String, dynamic> toMap(UserIdentityEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'handle': model.handle,
    };
  }
}

abstract class UserIdentityFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    handle,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String handle = 'handle';
}

const LoginSerializer loginSerializer = LoginSerializer();

class LoginEncoder extends Converter<Login, Map> {
  const LoginEncoder();

  @override
  Map convert(Login model) => LoginSerializer.toMap(model);
}

class LoginDecoder extends Converter<Map, Login> {
  const LoginDecoder();

  @override
  Login convert(Map map) => LoginSerializer.fromMap(map);
}

class LoginSerializer extends Codec<Login, Map> {
  const LoginSerializer();

  @override
  LoginEncoder get encoder => const LoginEncoder();

  @override
  LoginDecoder get decoder => const LoginDecoder();

  static Login fromMap(Map map) {
    return Login(
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
      userIdentity: map['user_identity'] != null
          ? UserIdentitySerializer.fromMap(map['user_identity'] as Map)
          : null,
      backupIdentity: map['backup_identity'] != null
          ? UserIdentitySerializer.fromMap(map['backup_identity'] as Map)
          : null,
      grants: map['grants'] is Iterable
          ? List.unmodifiable(
              ((map['grants'] as Iterable).whereType<Map>()).map(
                GrantSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  static Map<String, dynamic> toMap(LoginEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'user_identity': UserIdentitySerializer.toMap(model.userIdentity),
      'backup_identity': UserIdentitySerializer.toMap(model.backupIdentity),
      'grants': model.grants.map((m) => GrantSerializer.toMap(m)).toList(),
    };
  }
}

abstract class LoginFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    userIdentity,
    backupIdentity,
    grants,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String userIdentity = 'user_identity';

  static const String backupIdentity = 'backup_identity';

  static const String grants = 'grants';
}

const LoginGrantSerializer loginGrantSerializer = LoginGrantSerializer();

class LoginGrantEncoder extends Converter<LoginGrant, Map> {
  const LoginGrantEncoder();

  @override
  Map convert(LoginGrant model) => LoginGrantSerializer.toMap(model);
}

class LoginGrantDecoder extends Converter<Map, LoginGrant> {
  const LoginGrantDecoder();

  @override
  LoginGrant convert(Map map) => LoginGrantSerializer.fromMap(map);
}

class LoginGrantSerializer extends Codec<LoginGrant, Map> {
  const LoginGrantSerializer();

  @override
  LoginGrantEncoder get encoder => const LoginGrantEncoder();

  @override
  LoginGrantDecoder get decoder => const LoginGrantDecoder();

  static LoginGrant fromMap(Map map) {
    return LoginGrant(
      login: map['login'] != null
          ? LoginSerializer.fromMap(map['login'] as Map)
          : null,
      grant: map['grant'] != null
          ? GrantSerializer.fromMap(map['grant'] as Map)
          : null,
    );
  }

  static Map<String, dynamic> toMap(LoginGrantEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'login': LoginSerializer.toMap(model.login),
      'grant': GrantSerializer.toMap(model.grant),
    };
  }
}

abstract class LoginGrantFields {
  static const List<String> allFields = <String>[login, grant];

  static const String login = 'login';

  static const String grant = 'grant';
}

const GrantSerializer grantSerializer = GrantSerializer();

class GrantEncoder extends Converter<Grant, Map> {
  const GrantEncoder();

  @override
  Map convert(Grant model) => GrantSerializer.toMap(model);
}

class GrantDecoder extends Converter<Map, Grant> {
  const GrantDecoder();

  @override
  Grant convert(Map map) => GrantSerializer.fromMap(map);
}

class GrantSerializer extends Codec<Grant, Map> {
  const GrantSerializer();

  @override
  GrantEncoder get encoder => const GrantEncoder();

  @override
  GrantDecoder get decoder => const GrantDecoder();

  static Grant fromMap(Map map) {
    return Grant(
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
      logins: map['logins'] is Iterable
          ? List.unmodifiable(
              ((map['logins'] as Iterable).whereType<Map>()).map(
                LoginSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  static Map<String, dynamic> toMap(GrantEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'logins': model.logins.map((m) => LoginSerializer.toMap(m)).toList(),
    };
  }
}

abstract class GrantFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    logins,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String logins = 'logins';
}
