// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uuid_user.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class UuidUserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('uuid_users', (table) {
      table.declare('id', ColumnType.text).primaryKey();
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
          .declare('author_id', ColumnType.text)
          .references('uuid_users', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('uuid_posts');
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
    return [
      for (var (i, r) in records.indexed)
        r.copyWith(
          posts: postsByKey == null
              ? r.posts
              : [...?postsByKey['${valueOf('id', rows[i])}']],
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
  }) : posts = List.unmodifiable(posts);

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

  UuidUser copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    List<UuidPostEntity>? posts,
  }) {
    return UuidUser(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      posts: posts ?? this.posts,
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
            .equals(other.posts, posts);
  }

  @override
  int get hashCode {
    return Object.hashAll([id, createdAt, updatedAt, name, posts.length]);
  }

  @override
  String toString() {
    return 'UuidUser(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, posts=$posts)';
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
    );
  }

  /// Adds the JSON Schema of [UuidUser], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    UuidPostSerializer.addJsonSchemas(schemas);
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
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String posts = 'posts';
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
