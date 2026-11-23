// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uuid_user.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class UuidUserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('uuid_users', (table) {
      table.declare('id', ColumnType.uuid).primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('uuid_users', cascade: true);
  }
}

class UuidPostMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('uuid_posts', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('title', length: 255);
      table
          .declare('author_id', ColumnType.uuid)
          .references('uuid_users', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('uuid_posts');
  }
}

class UuidTagMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('uuid_tags', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('uuid_tags', cascade: true);
  }
}

class UuidUserTagMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('uuid_user_tags', (table) {
      table
          .declare('uuid_user_id', ColumnType.uuid)
          .references('uuid_users', 'id');
      table
          .declare('uuid_tag_id', ColumnType.int)
          .references('uuid_tags', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('uuid_user_tags');
  }
}

class UuidGroupMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('uuid_groups', (table) {
      table.declare('id', ColumnType.uuid).primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('uuid_groups', cascade: true);
  }
}

class UuidUserGroupMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('uuid_user_groups', (table) {
      table
          .declare('uuid_user_id', ColumnType.uuid)
          .references('uuid_users', 'id');
      table
          .declare('uuid_group_id', ColumnType.uuid)
          .references('uuid_groups', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('uuid_user_groups');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class UuidUserQuery extends Query<UuidUser, UuidUserQueryWhere> {
  UuidUserQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UuidUserQueryWhere(this);
  }

  @override
  final UuidUserQueryValues values = UuidUserQueryValues();

  List<String> _selectedFields = [];

  UuidUserQueryWhere? _where;

  late final UuidPostQuery _posts = UuidPostQuery();

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'uuid_users';
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

  UuidUserQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UuidUserQueryWhere? get where {
    return _where;
  }

  @override
  UuidUserQueryWhere newWhereClause() {
    return UuidUserQueryWhere(this);
  }

  Optional<UuidUser> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UuidUser(
      id: fields.contains('id') ? (row[fields.indexOf('id')] as String?) : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[fields.indexOf('created_at')])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[fields.indexOf('updated_at')])
          : null,
      name: fields.contains('name')
          ? (row[fields.indexOf('name')] as String?)
          : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<UuidUser> deserialize(List row) {
    return parseRow(row);
  }

  /// The query [posts] are loaded with, whose conditions and order apply.
  UuidPostQuery get posts {
    return _posts;
  }

  @override
  bool get loadsRelations => true;

  @override
  Future<List<UuidUser>> loadRelations(
    QueryExecutor executor,
    List<List> rows,
    List<UuidUser> records,
    Set<String> loading,
  ) async {
    if (records.isEmpty) return records;
    var postsByKey = loading.contains('uuid_posts')
        ? null
        : await _posts.getByKeys(executor, 'author_id', [
            for (var row in rows) valueOf('id', row),
          ], loading);
    // The other ends of the many-to-many, then their records.
    var tagsPivot = loading.contains('uuid_tags')
        ? null
        : await Query.pivotKeys(
            executor,
            'uuid_user_tags',
            'uuid_user_id',
            'uuid_tag_id',
            [for (var row in rows) valueOf('id', row)],
          );
    var tagsByKey = tagsPivot == null
        ? null
        : await UuidTagQuery().getByKeys(
            executor,
            'id',
            tagsPivot.values.expand((k) => k),
            loading,
          );
    // The other ends of the many-to-many, then their records.
    var groupsPivot = loading.contains('uuid_groups')
        ? null
        : await Query.pivotKeys(
            executor,
            'uuid_user_groups',
            'uuid_user_id',
            'uuid_group_id',
            [for (var row in rows) valueOf('id', row)],
          );
    var groupsByKey = groupsPivot == null
        ? null
        : await UuidGroupQuery().getByKeys(
            executor,
            'id',
            groupsPivot.values.expand((k) => k),
            loading,
          );
    return [
      for (var (i, r) in records.indexed)
        r.copyWith(
          posts: postsByKey == null
              ? r.posts
              : [...?postsByKey['${valueOf('id', rows[i])}']],
          tags: tagsByKey == null
              ? r.tags
              : [
                  for (var k
                      in tagsPivot!['${valueOf('id', rows[i])}'] ?? const [])
                    ...?tagsByKey['$k'],
                ],
          groups: groupsByKey == null
              ? r.groups
              : [
                  for (var k
                      in groupsPivot!['${valueOf('id', rows[i])}'] ?? const [])
                    ...?groupsByKey['$k'],
                ],
        ),
    ];
  }
}

class UuidUserQueryWhere extends QueryWhere {
  UuidUserQueryWhere(UuidUserQuery query)
    : id = StringSqlExpressionBuilder(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      name = StringSqlExpressionBuilder(query, 'name');

  final StringSqlExpressionBuilder id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, name];
  }
}

class UuidUserQueryValues extends MapQueryValues {
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

  void copyFrom(UuidUser model) {
    id = model.id;
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
  }
}

class UuidPostQuery extends Query<UuidPost, UuidPostQueryWhere> {
  UuidPostQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UuidPostQueryWhere(this);
    leftJoin(
      _author = UuidUserQuery(trampoline: trampoline, parent: this),
      'author_id',
      'id',
      additionalFields: const ['id', 'created_at', 'updated_at', 'name'],
      trampoline: trampoline,
    );
  }

  @override
  final UuidPostQueryValues values = UuidPostQueryValues();

  List<String> _selectedFields = [];

  UuidPostQueryWhere? _where;

  late UuidUserQuery _author;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'uuid_posts';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'title',
      'author_id',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  UuidPostQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UuidPostQueryWhere? get where {
    return _where;
  }

  @override
  UuidPostQueryWhere newWhereClause() {
    return UuidPostQueryWhere(this);
  }

  Optional<UuidPost> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UuidPost(
      id: fields.contains('id') ? row[fields.indexOf('id')].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[fields.indexOf('created_at')])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[fields.indexOf('updated_at')])
          : null,
      title: fields.contains('title')
          ? (row[fields.indexOf('title')] as String?)
          : null,
    );
    {
      var modelOpt = _author.parseRow(joinedRow(0, row));
      modelOpt.ifPresent((m) {
        model = model.copyWith(author: m);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<UuidPost> deserialize(List row) {
    return parseRow(row);
  }

  UuidUserQuery get author {
    return _author;
  }

  @override
  bool get loadsRelations => true;

  @override
  Future<List<UuidPost>> loadRelations(
    QueryExecutor executor,
    List<List> rows,
    List<UuidPost> records,
    Set<String> loading,
  ) async {
    if (records.isEmpty) return records;
    var authorLoaded = loading.contains('uuid_users')
        ? null
        : (await _author.loadRelations(
            executor,
            [
              for (var (i, r) in records.indexed)
                if (r.author != null) joinedRow(0, rows[i]),
            ],
            [
              for (var r in records)
                if (r.author != null) r.author as UuidUser,
            ],
            {...loading, 'uuid_users'},
          )).iterator;
    return [
      for (var r in records)
        r.copyWith(
          author: authorLoaded == null || r.author == null
              ? r.author
              : (authorLoaded..moveNext()).current,
        ),
    ];
  }
}

class UuidPostQueryWhere extends QueryWhere {
  UuidPostQueryWhere(UuidPostQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      title = StringSqlExpressionBuilder(query, 'title'),
      authorId = StringSqlExpressionBuilder(query, 'author_id');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder title;

  final StringSqlExpressionBuilder authorId;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, title, authorId];
  }
}

class UuidPostQueryValues extends MapQueryValues {
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

  String? get title {
    return (values['title'] as String?);
  }

  set title(String? value) => values['title'] = value;

  String? get authorId {
    return (values['author_id'] as String?);
  }

  set authorId(String? value) => values['author_id'] = value;

  void copyFrom(UuidPost model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    title = model.title;
    if (model.author != null) {
      values['author_id'] = model.author?.id;
    }
  }
}

class UuidTagQuery extends Query<UuidTag, UuidTagQueryWhere> {
  UuidTagQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UuidTagQueryWhere(this);
  }

  @override
  final UuidTagQueryValues values = UuidTagQueryValues();

  List<String> _selectedFields = [];

  UuidTagQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'uuid_tags';
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

  UuidTagQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UuidTagQueryWhere? get where {
    return _where;
  }

  @override
  UuidTagQueryWhere newWhereClause() {
    return UuidTagQueryWhere(this);
  }

  Optional<UuidTag> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UuidTag(
      id: fields.contains('id') ? row[fields.indexOf('id')].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[fields.indexOf('created_at')])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[fields.indexOf('updated_at')])
          : null,
      name: fields.contains('name')
          ? (row[fields.indexOf('name')] as String?)
          : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<UuidTag> deserialize(List row) {
    return parseRow(row);
  }

  @override
  bool get loadsRelations => true;

  @override
  Future<List<UuidTag>> loadRelations(
    QueryExecutor executor,
    List<List> rows,
    List<UuidTag> records,
    Set<String> loading,
  ) async {
    if (records.isEmpty) return records;
    // The other ends of the many-to-many, then their records.
    var usersPivot = loading.contains('uuid_users')
        ? null
        : await Query.pivotKeys(
            executor,
            'uuid_user_tags',
            'uuid_tag_id',
            'uuid_user_id',
            [for (var row in rows) valueOf('id', row)],
          );
    var usersByKey = usersPivot == null
        ? null
        : await UuidUserQuery().getByKeys(
            executor,
            'id',
            usersPivot.values.expand((k) => k),
            loading,
          );
    return [
      for (var (i, r) in records.indexed)
        r.copyWith(
          users: usersByKey == null
              ? r.users
              : [
                  for (var k
                      in usersPivot!['${valueOf('id', rows[i])}'] ?? const [])
                    ...?usersByKey['$k'],
                ],
        ),
    ];
  }
}

class UuidTagQueryWhere extends QueryWhere {
  UuidTagQueryWhere(UuidTagQuery query)
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

class UuidTagQueryValues extends MapQueryValues {
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

  void copyFrom(UuidTag model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
  }
}

class UuidUserTagQuery extends Query<UuidUserTag, UuidUserTagQueryWhere> {
  UuidUserTagQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UuidUserTagQueryWhere(this);
    leftJoin(
      _uuidUser = UuidUserQuery(trampoline: trampoline, parent: this),
      'uuid_user_id',
      'id',
      additionalFields: const ['id', 'created_at', 'updated_at', 'name'],
      trampoline: trampoline,
    );
    leftJoin(
      _uuidTag = UuidTagQuery(trampoline: trampoline, parent: this),
      'uuid_tag_id',
      'id',
      additionalFields: const ['id', 'created_at', 'updated_at', 'name'],
      trampoline: trampoline,
    );
  }

  @override
  final UuidUserTagQueryValues values = UuidUserTagQueryValues();

  List<String> _selectedFields = [];

  UuidUserTagQueryWhere? _where;

  late UuidUserQuery _uuidUser;

  late UuidTagQuery _uuidTag;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'uuid_user_tags';
  }

  @override
  List<String> get fields {
    const localFields = ['uuid_user_id', 'uuid_tag_id'];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  UuidUserTagQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UuidUserTagQueryWhere? get where {
    return _where;
  }

  @override
  UuidUserTagQueryWhere newWhereClause() {
    return UuidUserTagQueryWhere(this);
  }

  Optional<UuidUserTag> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UuidUserTag();
    {
      var modelOpt = _uuidUser.parseRow(joinedRow(0, row));
      modelOpt.ifPresent((m) {
        model = model.copyWith(uuidUser: m);
      });
    }
    {
      var modelOpt = _uuidTag.parseRow(joinedRow(1, row));
      modelOpt.ifPresent((m) {
        model = model.copyWith(uuidTag: m);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<UuidUserTag> deserialize(List row) {
    return parseRow(row);
  }

  UuidUserQuery get uuidUser {
    return _uuidUser;
  }

  UuidTagQuery get uuidTag {
    return _uuidTag;
  }

  @override
  bool get loadsRelations => true;

  @override
  Future<List<UuidUserTag>> loadRelations(
    QueryExecutor executor,
    List<List> rows,
    List<UuidUserTag> records,
    Set<String> loading,
  ) async {
    if (records.isEmpty) return records;
    var uuidUserLoaded = loading.contains('uuid_users')
        ? null
        : (await _uuidUser.loadRelations(
            executor,
            [
              for (var (i, r) in records.indexed)
                if (r.uuidUser != null) joinedRow(0, rows[i]),
            ],
            [
              for (var r in records)
                if (r.uuidUser != null) r.uuidUser as UuidUser,
            ],
            {...loading, 'uuid_users'},
          )).iterator;
    var uuidTagLoaded = loading.contains('uuid_tags')
        ? null
        : (await _uuidTag.loadRelations(
            executor,
            [
              for (var (i, r) in records.indexed)
                if (r.uuidTag != null) joinedRow(1, rows[i]),
            ],
            [
              for (var r in records)
                if (r.uuidTag != null) r.uuidTag as UuidTag,
            ],
            {...loading, 'uuid_tags'},
          )).iterator;
    return [
      for (var r in records)
        r.copyWith(
          uuidUser: uuidUserLoaded == null || r.uuidUser == null
              ? r.uuidUser
              : (uuidUserLoaded..moveNext()).current,
          uuidTag: uuidTagLoaded == null || r.uuidTag == null
              ? r.uuidTag
              : (uuidTagLoaded..moveNext()).current,
        ),
    ];
  }
}

class UuidUserTagQueryWhere extends QueryWhere {
  UuidUserTagQueryWhere(UuidUserTagQuery query)
    : uuidUserId = StringSqlExpressionBuilder(query, 'uuid_user_id'),
      uuidTagId = NumericSqlExpressionBuilder<int>(query, 'uuid_tag_id');

  final StringSqlExpressionBuilder uuidUserId;

  final NumericSqlExpressionBuilder<int> uuidTagId;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [uuidUserId, uuidTagId];
  }
}

class UuidUserTagQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get uuidUserId {
    return (values['uuid_user_id'] as String?);
  }

  set uuidUserId(String? value) => values['uuid_user_id'] = value;

  int? get uuidTagId {
    return (values['uuid_tag_id'] as int?);
  }

  set uuidTagId(int? value) => values['uuid_tag_id'] = value;

  void copyFrom(UuidUserTag model) {
    if (model.uuidUser != null) {
      values['uuid_user_id'] = model.uuidUser?.id;
    }
    if (model.uuidTag?.id != null) {
      values['uuid_tag_id'] = int.parse(model.uuidTag!.id!);
    }
  }
}

class UuidGroupQuery extends Query<UuidGroup, UuidGroupQueryWhere> {
  UuidGroupQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UuidGroupQueryWhere(this);
  }

  @override
  final UuidGroupQueryValues values = UuidGroupQueryValues();

  List<String> _selectedFields = [];

  UuidGroupQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'uuid_groups';
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

  UuidGroupQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UuidGroupQueryWhere? get where {
    return _where;
  }

  @override
  UuidGroupQueryWhere newWhereClause() {
    return UuidGroupQueryWhere(this);
  }

  Optional<UuidGroup> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UuidGroup(
      id: fields.contains('id') ? (row[fields.indexOf('id')] as String?) : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[fields.indexOf('created_at')])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[fields.indexOf('updated_at')])
          : null,
      name: fields.contains('name')
          ? (row[fields.indexOf('name')] as String?)
          : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<UuidGroup> deserialize(List row) {
    return parseRow(row);
  }

  @override
  bool get loadsRelations => true;

  @override
  Future<List<UuidGroup>> loadRelations(
    QueryExecutor executor,
    List<List> rows,
    List<UuidGroup> records,
    Set<String> loading,
  ) async {
    if (records.isEmpty) return records;
    // The other ends of the many-to-many, then their records.
    var usersPivot = loading.contains('uuid_users')
        ? null
        : await Query.pivotKeys(
            executor,
            'uuid_user_groups',
            'uuid_group_id',
            'uuid_user_id',
            [for (var row in rows) valueOf('id', row)],
          );
    var usersByKey = usersPivot == null
        ? null
        : await UuidUserQuery().getByKeys(
            executor,
            'id',
            usersPivot.values.expand((k) => k),
            loading,
          );
    return [
      for (var (i, r) in records.indexed)
        r.copyWith(
          users: usersByKey == null
              ? r.users
              : [
                  for (var k
                      in usersPivot!['${valueOf('id', rows[i])}'] ?? const [])
                    ...?usersByKey['$k'],
                ],
        ),
    ];
  }
}

class UuidGroupQueryWhere extends QueryWhere {
  UuidGroupQueryWhere(UuidGroupQuery query)
    : id = StringSqlExpressionBuilder(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      name = StringSqlExpressionBuilder(query, 'name');

  final StringSqlExpressionBuilder id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, name];
  }
}

class UuidGroupQueryValues extends MapQueryValues {
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

  void copyFrom(UuidGroup model) {
    id = model.id;
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
  }
}

class UuidUserGroupQuery extends Query<UuidUserGroup, UuidUserGroupQueryWhere> {
  UuidUserGroupQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = UuidUserGroupQueryWhere(this);
    leftJoin(
      _uuidUser = UuidUserQuery(trampoline: trampoline, parent: this),
      'uuid_user_id',
      'id',
      additionalFields: const ['id', 'created_at', 'updated_at', 'name'],
      trampoline: trampoline,
    );
    leftJoin(
      _uuidGroup = UuidGroupQuery(trampoline: trampoline, parent: this),
      'uuid_group_id',
      'id',
      additionalFields: const ['id', 'created_at', 'updated_at', 'name'],
      trampoline: trampoline,
    );
  }

  @override
  final UuidUserGroupQueryValues values = UuidUserGroupQueryValues();

  List<String> _selectedFields = [];

  UuidUserGroupQueryWhere? _where;

  late UuidUserQuery _uuidUser;

  late UuidGroupQuery _uuidGroup;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'uuid_user_groups';
  }

  @override
  List<String> get fields {
    const localFields = ['uuid_user_id', 'uuid_group_id'];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  UuidUserGroupQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  UuidUserGroupQueryWhere? get where {
    return _where;
  }

  @override
  UuidUserGroupQueryWhere newWhereClause() {
    return UuidUserGroupQueryWhere(this);
  }

  Optional<UuidUserGroup> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = UuidUserGroup();
    {
      var modelOpt = _uuidUser.parseRow(joinedRow(0, row));
      modelOpt.ifPresent((m) {
        model = model.copyWith(uuidUser: m);
      });
    }
    {
      var modelOpt = _uuidGroup.parseRow(joinedRow(1, row));
      modelOpt.ifPresent((m) {
        model = model.copyWith(uuidGroup: m);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<UuidUserGroup> deserialize(List row) {
    return parseRow(row);
  }

  UuidUserQuery get uuidUser {
    return _uuidUser;
  }

  UuidGroupQuery get uuidGroup {
    return _uuidGroup;
  }

  @override
  bool get loadsRelations => true;

  @override
  Future<List<UuidUserGroup>> loadRelations(
    QueryExecutor executor,
    List<List> rows,
    List<UuidUserGroup> records,
    Set<String> loading,
  ) async {
    if (records.isEmpty) return records;
    var uuidUserLoaded = loading.contains('uuid_users')
        ? null
        : (await _uuidUser.loadRelations(
            executor,
            [
              for (var (i, r) in records.indexed)
                if (r.uuidUser != null) joinedRow(0, rows[i]),
            ],
            [
              for (var r in records)
                if (r.uuidUser != null) r.uuidUser as UuidUser,
            ],
            {...loading, 'uuid_users'},
          )).iterator;
    var uuidGroupLoaded = loading.contains('uuid_groups')
        ? null
        : (await _uuidGroup.loadRelations(
            executor,
            [
              for (var (i, r) in records.indexed)
                if (r.uuidGroup != null) joinedRow(1, rows[i]),
            ],
            [
              for (var r in records)
                if (r.uuidGroup != null) r.uuidGroup as UuidGroup,
            ],
            {...loading, 'uuid_groups'},
          )).iterator;
    return [
      for (var r in records)
        r.copyWith(
          uuidUser: uuidUserLoaded == null || r.uuidUser == null
              ? r.uuidUser
              : (uuidUserLoaded..moveNext()).current,
          uuidGroup: uuidGroupLoaded == null || r.uuidGroup == null
              ? r.uuidGroup
              : (uuidGroupLoaded..moveNext()).current,
        ),
    ];
  }
}

class UuidUserGroupQueryWhere extends QueryWhere {
  UuidUserGroupQueryWhere(UuidUserGroupQuery query)
    : uuidUserId = StringSqlExpressionBuilder(query, 'uuid_user_id'),
      uuidGroupId = StringSqlExpressionBuilder(query, 'uuid_group_id');

  final StringSqlExpressionBuilder uuidUserId;

  final StringSqlExpressionBuilder uuidGroupId;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [uuidUserId, uuidGroupId];
  }
}

class UuidUserGroupQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get uuidUserId {
    return (values['uuid_user_id'] as String?);
  }

  set uuidUserId(String? value) => values['uuid_user_id'] = value;

  String? get uuidGroupId {
    return (values['uuid_group_id'] as String?);
  }

  set uuidGroupId(String? value) => values['uuid_group_id'] = value;

  void copyFrom(UuidUserGroup model) {
    if (model.uuidUser != null) {
      values['uuid_user_id'] = model.uuidUser?.id;
    }
    if (model.uuidGroup != null) {
      values['uuid_group_id'] = model.uuidGroup?.id;
    }
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class UuidUser extends UuidUserEntity {
  UuidUser({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name,
    List<UuidPostEntity> posts = const [],
    List<UuidTagEntity> tags = const [],
    List<UuidGroupEntity> groups = const [],
  }) : posts = List.unmodifiable(posts),
       tags = List.unmodifiable(tags),
       groups = List.unmodifiable(groups);

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
  List<UuidPostEntity> posts;

  @override
  List<UuidTagEntity> tags;

  @override
  List<UuidGroupEntity> groups;

  UuidUser copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    List<UuidPostEntity>? posts,
    List<UuidTagEntity>? tags,
    List<UuidGroupEntity>? groups,
  }) {
    return UuidUser(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      posts: posts ?? this.posts,
      tags: tags ?? this.tags,
      groups: groups ?? this.groups,
    );
  }

  @override
  bool operator ==(other) {
    return other is UuidUserEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        ListEquality<UuidPostEntity>(DefaultEquality<UuidPostEntity>())
            .equals(other.posts, posts) &&
        ListEquality<UuidTagEntity>(DefaultEquality<UuidTagEntity>())
            .equals(other.tags, tags) &&
        ListEquality<UuidGroupEntity>(DefaultEquality<UuidGroupEntity>())
            .equals(other.groups, groups);
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      createdAt,
      updatedAt,
      name,
      posts.length,
      tags.length,
      groups.length,
    ]);
  }

  @override
  String toString() {
    return 'UuidUser(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, posts=$posts, tags=$tags, groups=$groups)';
  }

  Map<String, dynamic> toJson() {
    return UuidUserSerializer.toMap(this);
  }
}

@generatedSerializable
class UuidPost extends UuidPostEntity {
  UuidPost({this.id, this.createdAt, this.updatedAt, this.title, this.author});

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
  String? title;

  @override
  UuidUserEntity? author;

  UuidPost copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    UuidUserEntity? author,
  }) {
    return UuidPost(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      author: author ?? this.author,
    );
  }

  @override
  bool operator ==(other) {
    return other is UuidPostEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.title == title &&
        other.author == author;
  }

  @override
  int get hashCode {
    return Object.hashAll([id, createdAt, updatedAt, title, author]);
  }

  @override
  String toString() {
    return 'UuidPost(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, title=$title, author=$author)';
  }

  Map<String, dynamic> toJson() {
    return UuidPostSerializer.toMap(this);
  }
}

@generatedSerializable
class UuidTag extends UuidTagEntity {
  UuidTag({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name,
    List<UuidUserEntity> users = const [],
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
  List<UuidUserEntity> users;

  UuidTag copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    List<UuidUserEntity>? users,
  }) {
    return UuidTag(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      users: users ?? this.users,
    );
  }

  @override
  bool operator ==(other) {
    return other is UuidTagEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        ListEquality<UuidUserEntity>(DefaultEquality<UuidUserEntity>())
            .equals(other.users, users);
  }

  @override
  int get hashCode {
    return Object.hashAll([id, createdAt, updatedAt, name, users.length]);
  }

  @override
  String toString() {
    return 'UuidTag(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, users=$users)';
  }

  Map<String, dynamic> toJson() {
    return UuidTagSerializer.toMap(this);
  }
}

@generatedSerializable
class UuidUserTag implements UuidUserTagEntity {
  UuidUserTag({this.uuidUser, this.uuidTag});

  @override
  UuidUserEntity? uuidUser;

  @override
  UuidTagEntity? uuidTag;

  UuidUserTag copyWith({UuidUserEntity? uuidUser, UuidTagEntity? uuidTag}) {
    return UuidUserTag(
      uuidUser: uuidUser ?? this.uuidUser,
      uuidTag: uuidTag ?? this.uuidTag,
    );
  }

  @override
  bool operator ==(other) {
    return other is UuidUserTagEntity &&
        other.uuidUser == uuidUser &&
        other.uuidTag == uuidTag;
  }

  @override
  int get hashCode {
    return Object.hashAll([uuidUser, uuidTag]);
  }

  @override
  String toString() {
    return 'UuidUserTag(uuidUser=$uuidUser, uuidTag=$uuidTag)';
  }

  Map<String, dynamic> toJson() {
    return UuidUserTagSerializer.toMap(this);
  }
}

@generatedSerializable
class UuidGroup extends UuidGroupEntity {
  UuidGroup({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name,
    List<UuidUserEntity> users = const [],
  }) : users = List.unmodifiable(users);

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
  List<UuidUserEntity> users;

  UuidGroup copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    List<UuidUserEntity>? users,
  }) {
    return UuidGroup(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      users: users ?? this.users,
    );
  }

  @override
  bool operator ==(other) {
    return other is UuidGroupEntity &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        ListEquality<UuidUserEntity>(DefaultEquality<UuidUserEntity>())
            .equals(other.users, users);
  }

  @override
  int get hashCode {
    return Object.hashAll([id, createdAt, updatedAt, name, users.length]);
  }

  @override
  String toString() {
    return 'UuidGroup(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, users=$users)';
  }

  Map<String, dynamic> toJson() {
    return UuidGroupSerializer.toMap(this);
  }
}

@generatedSerializable
class UuidUserGroup implements UuidUserGroupEntity {
  UuidUserGroup({this.uuidUser, this.uuidGroup});

  @override
  UuidUserEntity? uuidUser;

  @override
  UuidGroupEntity? uuidGroup;

  UuidUserGroup copyWith({
    UuidUserEntity? uuidUser,
    UuidGroupEntity? uuidGroup,
  }) {
    return UuidUserGroup(
      uuidUser: uuidUser ?? this.uuidUser,
      uuidGroup: uuidGroup ?? this.uuidGroup,
    );
  }

  @override
  bool operator ==(other) {
    return other is UuidUserGroupEntity &&
        other.uuidUser == uuidUser &&
        other.uuidGroup == uuidGroup;
  }

  @override
  int get hashCode {
    return Object.hashAll([uuidUser, uuidGroup]);
  }

  @override
  String toString() {
    return 'UuidUserGroup(uuidUser=$uuidUser, uuidGroup=$uuidGroup)';
  }

  Map<String, dynamic> toJson() {
    return UuidUserGroupSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const UuidUserSerializer uuidUserSerializer = UuidUserSerializer();

class UuidUserEncoder extends Converter<UuidUser, Map> {
  const UuidUserEncoder();

  @override
  Map convert(UuidUser model) => UuidUserSerializer.toMap(model);
}

class UuidUserDecoder extends Converter<Map, UuidUser> {
  const UuidUserDecoder();

  @override
  UuidUser convert(Map map) => UuidUserSerializer.fromMap(map);
}

class UuidUserSerializer extends Codec<UuidUser, Map> {
  const UuidUserSerializer();

  /// The name of the JSON Schema of [UuidUser].
  static const String schemaName = 'UuidUser';

  /// The JSON Schema of the map that [toMap] writes of [UuidUser], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'id': {
        'type': ['string', 'null'],
      },
      'created_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'updated_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'name': {
        'type': ['string', 'null'],
      },
      'posts': {
        'type': 'array',
        'items': {'\$ref': '#/components/schemas/UuidPost'},
      },
      'tags': {
        'type': 'array',
        'items': {'\$ref': '#/components/schemas/UuidTag'},
      },
      'groups': {
        'type': 'array',
        'items': {'\$ref': '#/components/schemas/UuidGroup'},
      },
    },
  };

  @override
  UuidUserEncoder get encoder => const UuidUserEncoder();

  @override
  UuidUserDecoder get decoder => const UuidUserDecoder();

  static UuidUser fromMap(Map map) {
    return UuidUser(
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
      posts: map['posts'] is Iterable
          ? List.unmodifiable(
              ((map['posts'] as Iterable).whereType<Map>()).map(
                UuidPostSerializer.fromMap,
              ),
            )
          : [],
      tags: map['tags'] is Iterable
          ? List.unmodifiable(
              ((map['tags'] as Iterable).whereType<Map>()).map(
                UuidTagSerializer.fromMap,
              ),
            )
          : [],
      groups: map['groups'] is Iterable
          ? List.unmodifiable(
              ((map['groups'] as Iterable).whereType<Map>()).map(
                UuidGroupSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  /// Adds the JSON Schema of [UuidUser], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    UuidPostSerializer.addJsonSchemas(schemas);
    UuidTagSerializer.addJsonSchemas(schemas);
    UuidGroupSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(UuidUserEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'posts': model.posts.map((m) => UuidPostSerializer.toMap(m)).toList(),
      'tags': model.tags.map((m) => UuidTagSerializer.toMap(m)).toList(),
      'groups': model.groups.map((m) => UuidGroupSerializer.toMap(m)).toList(),
    };
  }
}

abstract class UuidUserFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    posts,
    tags,
    groups,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String posts = 'posts';

  static const String tags = 'tags';

  static const String groups = 'groups';
}

const UuidPostSerializer uuidPostSerializer = UuidPostSerializer();

class UuidPostEncoder extends Converter<UuidPost, Map> {
  const UuidPostEncoder();

  @override
  Map convert(UuidPost model) => UuidPostSerializer.toMap(model);
}

class UuidPostDecoder extends Converter<Map, UuidPost> {
  const UuidPostDecoder();

  @override
  UuidPost convert(Map map) => UuidPostSerializer.fromMap(map);
}

class UuidPostSerializer extends Codec<UuidPost, Map> {
  const UuidPostSerializer();

  /// The name of the JSON Schema of [UuidPost].
  static const String schemaName = 'UuidPost';

  /// The JSON Schema of the map that [toMap] writes of [UuidPost], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'id': {
        'type': ['string', 'null'],
      },
      'created_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'updated_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'title': {
        'type': ['string', 'null'],
      },
      'author': {
        'anyOf': [
          {'\$ref': '#/components/schemas/UuidUser'},
          {'type': 'null'},
        ],
      },
    },
  };

  @override
  UuidPostEncoder get encoder => const UuidPostEncoder();

  @override
  UuidPostDecoder get decoder => const UuidPostDecoder();

  static UuidPost fromMap(Map map) {
    return UuidPost(
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
      title: map['title'] as String?,
      author: map['author'] != null
          ? UuidUserSerializer.fromMap(map['author'] as Map)
          : null,
    );
  }

  /// Adds the JSON Schema of [UuidPost], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    UuidUserSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(UuidPostEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'title': model.title,
      'author': model.author == null
          ? null
          : UuidUserSerializer.toMap(model.author),
    };
  }
}

abstract class UuidPostFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    title,
    author,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String title = 'title';

  static const String author = 'author';
}

const UuidTagSerializer uuidTagSerializer = UuidTagSerializer();

class UuidTagEncoder extends Converter<UuidTag, Map> {
  const UuidTagEncoder();

  @override
  Map convert(UuidTag model) => UuidTagSerializer.toMap(model);
}

class UuidTagDecoder extends Converter<Map, UuidTag> {
  const UuidTagDecoder();

  @override
  UuidTag convert(Map map) => UuidTagSerializer.fromMap(map);
}

class UuidTagSerializer extends Codec<UuidTag, Map> {
  const UuidTagSerializer();

  /// The name of the JSON Schema of [UuidTag].
  static const String schemaName = 'UuidTag';

  /// The JSON Schema of the map that [toMap] writes of [UuidTag], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'id': {
        'type': ['string', 'null'],
      },
      'created_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'updated_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'name': {
        'type': ['string', 'null'],
      },
      'users': {
        'type': 'array',
        'items': {'\$ref': '#/components/schemas/UuidUser'},
      },
    },
  };

  @override
  UuidTagEncoder get encoder => const UuidTagEncoder();

  @override
  UuidTagDecoder get decoder => const UuidTagDecoder();

  static UuidTag fromMap(Map map) {
    return UuidTag(
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
                UuidUserSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  /// Adds the JSON Schema of [UuidTag], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    UuidUserSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(UuidTagEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'users': model.users.map((m) => UuidUserSerializer.toMap(m)).toList(),
    };
  }
}

abstract class UuidTagFields {
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

const UuidUserTagSerializer uuidUserTagSerializer = UuidUserTagSerializer();

class UuidUserTagEncoder extends Converter<UuidUserTag, Map> {
  const UuidUserTagEncoder();

  @override
  Map convert(UuidUserTag model) => UuidUserTagSerializer.toMap(model);
}

class UuidUserTagDecoder extends Converter<Map, UuidUserTag> {
  const UuidUserTagDecoder();

  @override
  UuidUserTag convert(Map map) => UuidUserTagSerializer.fromMap(map);
}

class UuidUserTagSerializer extends Codec<UuidUserTag, Map> {
  const UuidUserTagSerializer();

  /// The name of the JSON Schema of [UuidUserTag].
  static const String schemaName = 'UuidUserTag';

  /// The JSON Schema of the map that [toMap] writes of [UuidUserTag], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'uuid_user': {
        'anyOf': [
          {'\$ref': '#/components/schemas/UuidUser'},
          {'type': 'null'},
        ],
      },
      'uuid_tag': {
        'anyOf': [
          {'\$ref': '#/components/schemas/UuidTag'},
          {'type': 'null'},
        ],
      },
    },
  };

  @override
  UuidUserTagEncoder get encoder => const UuidUserTagEncoder();

  @override
  UuidUserTagDecoder get decoder => const UuidUserTagDecoder();

  static UuidUserTag fromMap(Map map) {
    return UuidUserTag(
      uuidUser: map['uuid_user'] != null
          ? UuidUserSerializer.fromMap(map['uuid_user'] as Map)
          : null,
      uuidTag: map['uuid_tag'] != null
          ? UuidTagSerializer.fromMap(map['uuid_tag'] as Map)
          : null,
    );
  }

  /// Adds the JSON Schema of [UuidUserTag], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    UuidUserSerializer.addJsonSchemas(schemas);
    UuidTagSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(UuidUserTagEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'uuid_user': model.uuidUser == null
          ? null
          : UuidUserSerializer.toMap(model.uuidUser),
      'uuid_tag': model.uuidTag == null
          ? null
          : UuidTagSerializer.toMap(model.uuidTag),
    };
  }
}

abstract class UuidUserTagFields {
  static const List<String> allFields = <String>[uuidUser, uuidTag];

  static const String uuidUser = 'uuid_user';

  static const String uuidTag = 'uuid_tag';
}

const UuidGroupSerializer uuidGroupSerializer = UuidGroupSerializer();

class UuidGroupEncoder extends Converter<UuidGroup, Map> {
  const UuidGroupEncoder();

  @override
  Map convert(UuidGroup model) => UuidGroupSerializer.toMap(model);
}

class UuidGroupDecoder extends Converter<Map, UuidGroup> {
  const UuidGroupDecoder();

  @override
  UuidGroup convert(Map map) => UuidGroupSerializer.fromMap(map);
}

class UuidGroupSerializer extends Codec<UuidGroup, Map> {
  const UuidGroupSerializer();

  /// The name of the JSON Schema of [UuidGroup].
  static const String schemaName = 'UuidGroup';

  /// The JSON Schema of the map that [toMap] writes of [UuidGroup], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'id': {
        'type': ['string', 'null'],
      },
      'created_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'updated_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'name': {
        'type': ['string', 'null'],
      },
      'users': {
        'type': 'array',
        'items': {'\$ref': '#/components/schemas/UuidUser'},
      },
    },
  };

  @override
  UuidGroupEncoder get encoder => const UuidGroupEncoder();

  @override
  UuidGroupDecoder get decoder => const UuidGroupDecoder();

  static UuidGroup fromMap(Map map) {
    return UuidGroup(
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
                UuidUserSerializer.fromMap,
              ),
            )
          : [],
    );
  }

  /// Adds the JSON Schema of [UuidGroup], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    UuidUserSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(UuidGroupEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'users': model.users.map((m) => UuidUserSerializer.toMap(m)).toList(),
    };
  }
}

abstract class UuidGroupFields {
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

const UuidUserGroupSerializer uuidUserGroupSerializer =
    UuidUserGroupSerializer();

class UuidUserGroupEncoder extends Converter<UuidUserGroup, Map> {
  const UuidUserGroupEncoder();

  @override
  Map convert(UuidUserGroup model) => UuidUserGroupSerializer.toMap(model);
}

class UuidUserGroupDecoder extends Converter<Map, UuidUserGroup> {
  const UuidUserGroupDecoder();

  @override
  UuidUserGroup convert(Map map) => UuidUserGroupSerializer.fromMap(map);
}

class UuidUserGroupSerializer extends Codec<UuidUserGroup, Map> {
  const UuidUserGroupSerializer();

  /// The name of the JSON Schema of [UuidUserGroup].
  static const String schemaName = 'UuidUserGroup';

  /// The JSON Schema of the map that [toMap] writes of [UuidUserGroup], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'uuid_user': {
        'anyOf': [
          {'\$ref': '#/components/schemas/UuidUser'},
          {'type': 'null'},
        ],
      },
      'uuid_group': {
        'anyOf': [
          {'\$ref': '#/components/schemas/UuidGroup'},
          {'type': 'null'},
        ],
      },
    },
  };

  @override
  UuidUserGroupEncoder get encoder => const UuidUserGroupEncoder();

  @override
  UuidUserGroupDecoder get decoder => const UuidUserGroupDecoder();

  static UuidUserGroup fromMap(Map map) {
    return UuidUserGroup(
      uuidUser: map['uuid_user'] != null
          ? UuidUserSerializer.fromMap(map['uuid_user'] as Map)
          : null,
      uuidGroup: map['uuid_group'] != null
          ? UuidGroupSerializer.fromMap(map['uuid_group'] as Map)
          : null,
    );
  }

  /// Adds the JSON Schema of [UuidUserGroup], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    UuidUserSerializer.addJsonSchemas(schemas);
    UuidGroupSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(UuidUserGroupEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'uuid_user': model.uuidUser == null
          ? null
          : UuidUserSerializer.toMap(model.uuidUser),
      'uuid_group': model.uuidGroup == null
          ? null
          : UuidGroupSerializer.toMap(model.uuidGroup),
    };
  }
}

abstract class UuidUserGroupFields {
  static const List<String> allFields = <String>[uuidUser, uuidGroup];

  static const String uuidUser = 'uuid_user';

  static const String uuidGroup = 'uuid_group';
}
