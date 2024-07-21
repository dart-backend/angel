// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class BookMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create(
      'books',
      (table) {
        table.serial('id').primaryKey();
        table.timeStamp('created_at');
        table.timeStamp('updated_at');
        table.varChar(
          'name',
          length: 255,
        );
        table
            .declare(
              'author_id',
              ColumnType('int'),
            )
            .references(
              'authors',
              'id',
            );
        table
            .declare(
              'partner_author_id',
              ColumnType('int'),
            )
            .references(
              'authors',
              'id',
            );
      },
    );
  }

  @override
  void down(Schema schema) {
    schema.drop('books');
  }
}

class AuthorMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create(
      'authors',
      (table) {
        table.serial('id').primaryKey();
        table.timeStamp('created_at');
        table.timeStamp('updated_at');
        table.varChar(
          'name',
          length: 255,
        )
          ..defaultsTo('Tobe Osakwe')
          ..unique();
      },
    );
  }

  @override
  void down(Schema schema) {
    schema.drop('authors');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class BookQuery extends Query<Book, BookQueryWhere> {
  BookQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = BookQueryWhere(this);
    join(
      _author = AuthorQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'author_id',
      'id',
      additionalFields: const [
        'id',
        'created_at',
        'updated_at',
        'name',
      ],
      trampoline: trampoline,
    );
    join(
      _partnerAuthor = AuthorQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'partner_author_id',
      'id',
      additionalFields: const [
        'id',
        'created_at',
        'updated_at',
        'name',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final BookQueryValues values = BookQueryValues();

  List<String> _selectedFields = [];

  BookQueryWhere? _where;

  late AuthorQuery _author;

  late AuthorQuery _partnerAuthor;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'books';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
      'author_id',
      'partner_author_id',
      'name',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  BookQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  BookQueryWhere? get where {
    return _where;
  }

  @override
  BookQueryWhere newWhereClause() {
    return BookQueryWhere(this);
  }

  Optional<Book> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Book(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      name: fields.contains('name') ? (row[5] as String?) : null,
    );
    if (row.length > 6) {
      var modelOpt = AuthorQuery().parseRow(row.skip(6).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(author: m);
      });
    }
    if (row.length > 10) {
      var modelOpt = AuthorQuery().parseRow(row.skip(10).take(4).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(partnerAuthor: m);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<Book> deserialize(List row) {
    return parseRow(row);
  }

  AuthorQuery get author {
    return _author;
  }

  AuthorQuery get partnerAuthor {
    return _partnerAuthor;
  }
}

class BookQueryWhere extends QueryWhere {
  BookQueryWhere(BookQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        createdAt = DateTimeSqlExpressionBuilder(
          query,
          'created_at',
        ),
        updatedAt = DateTimeSqlExpressionBuilder(
          query,
          'updated_at',
        ),
        authorId = NumericSqlExpressionBuilder<int>(
          query,
          'author_id',
        ),
        partnerAuthorId = NumericSqlExpressionBuilder<int>(
          query,
          'partner_author_id',
        ),
        name = StringSqlExpressionBuilder(
          query,
          'name',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final NumericSqlExpressionBuilder<int> authorId;

  final NumericSqlExpressionBuilder<int> partnerAuthorId;

  final StringSqlExpressionBuilder name;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      authorId,
      partnerAuthorId,
      name,
    ];
  }
}

class BookQueryValues extends MapQueryValues {
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
  int get authorId {
    return (values['author_id'] as int);
  }

  set authorId(int value) => values['author_id'] = value;
  int get partnerAuthorId {
    return (values['partner_author_id'] as int);
  }

  set partnerAuthorId(int value) => values['partner_author_id'] = value;
  String? get name {
    return (values['name'] as String?);
  }

  set name(String? value) => values['name'] = value;
  void copyFrom(Book model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
    if (model.author != null) {
      values['author_id'] = model.author?.id;
    }
    if (model.partnerAuthor != null) {
      values['partner_author_id'] = model.partnerAuthor?.id;
    }
  }
}

class AuthorQuery extends Query<Author, AuthorQueryWhere> {
  AuthorQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = AuthorQueryWhere(this);
  }

  @override
  final AuthorQueryValues values = AuthorQueryValues();

  List<String> _selectedFields = [];

  AuthorQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'authors';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
      'name',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  AuthorQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  AuthorQueryWhere? get where {
    return _where;
  }

  @override
  AuthorQueryWhere newWhereClause() {
    return AuthorQueryWhere(this);
  }

  Optional<Author> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Author(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      name: fields.contains('name') ? (row[3] as String?) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Author> deserialize(List row) {
    return parseRow(row);
  }
}

class AuthorQueryWhere extends QueryWhere {
  AuthorQueryWhere(AuthorQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        createdAt = DateTimeSqlExpressionBuilder(
          query,
          'created_at',
        ),
        updatedAt = DateTimeSqlExpressionBuilder(
          query,
          'updated_at',
        ),
        name = StringSqlExpressionBuilder(
          query,
          'name',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      name,
    ];
  }
}

class AuthorQueryValues extends MapQueryValues {
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
  void copyFrom(Author model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Book extends _Book {
  Book({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.author,
    this.partnerAuthor,
    this.name,
  });

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
  _Author? author;

  @override
  _Author? partnerAuthor;

  @override
  String? name;

  Book copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    _Author? author,
    _Author? partnerAuthor,
    String? name,
  }) {
    return Book(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        author: author ?? this.author,
        partnerAuthor: partnerAuthor ?? this.partnerAuthor,
        name: name ?? this.name);
  }

  @override
  bool operator ==(other) {
    return other is _Book &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.author == author &&
        other.partnerAuthor == partnerAuthor &&
        other.name == name;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      author,
      partnerAuthor,
      name,
    ]);
  }

  @override
  String toString() {
    return 'Book(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, author=$author, partnerAuthor=$partnerAuthor, name=$name)';
  }

  Map<String, dynamic> toJson() {
    return BookSerializer.toMap(this);
  }
}

@generatedSerializable
class Author extends _Author {
  Author({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name = 'Tobe Osakwe',
  });

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

  Author copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
  }) {
    return Author(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        name: name ?? this.name);
  }

  @override
  bool operator ==(other) {
    return other is _Author &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      name,
    ]);
  }

  @override
  String toString() {
    return 'Author(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name)';
  }

  Map<String, dynamic> toJson() {
    return AuthorSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const BookSerializer bookSerializer = BookSerializer();

class BookEncoder extends Converter<Book, Map> {
  const BookEncoder();

  @override
  Map convert(Book model) => BookSerializer.toMap(model);
}

class BookDecoder extends Converter<Map, Book> {
  const BookDecoder();

  @override
  Book convert(Map map) => BookSerializer.fromMap(map);
}

class BookSerializer extends Codec<Book, Map> {
  const BookSerializer();

  @override
  BookEncoder get encoder => const BookEncoder();
  @override
  BookDecoder get decoder => const BookDecoder();
  static Book fromMap(Map map) {
    return Book(
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
        author: map['author'] != null
            ? AuthorSerializer.fromMap(map['author'] as Map)
            : null,
        partnerAuthor: map['partner_author'] != null
            ? AuthorSerializer.fromMap(map['partner_author'] as Map)
            : null,
        name: map['name'] as String?);
  }

  static Map<String, dynamic> toMap(_Book? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'author': AuthorSerializer.toMap(model.author),
      'partner_author': AuthorSerializer.toMap(model.partnerAuthor),
      'name': model.name
    };
  }
}

abstract class BookFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    author,
    partnerAuthor,
    name,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String author = 'author';

  static const String partnerAuthor = 'partner_author';

  static const String name = 'name';
}

const AuthorSerializer authorSerializer = AuthorSerializer();

class AuthorEncoder extends Converter<Author, Map> {
  const AuthorEncoder();

  @override
  Map convert(Author model) => AuthorSerializer.toMap(model);
}

class AuthorDecoder extends Converter<Map, Author> {
  const AuthorDecoder();

  @override
  Author convert(Map map) => AuthorSerializer.fromMap(map);
}

class AuthorSerializer extends Codec<Author, Map> {
  const AuthorSerializer();

  @override
  AuthorEncoder get encoder => const AuthorEncoder();
  @override
  AuthorDecoder get decoder => const AuthorDecoder();
  static Author fromMap(Map map) {
    return Author(
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
        name: map['name'] as String? ?? 'Tobe Osakwe');
  }

  static Map<String, dynamic> toMap(_Author? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name
    };
  }
}

abstract class AuthorFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';
}
