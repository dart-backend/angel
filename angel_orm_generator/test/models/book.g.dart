// GENERATED CODE - DO NOT MODIFY BY HAND

part of angel_orm.generator.models.book;

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class BookMigration extends Migration {
  @override
  up(Schema schema) {
    schema.create('books', (table) {
      table.serial('id')..primaryKey();
      table.varChar('name');
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.integer('author_id').references('authors', 'id');
      table.integer('partner_author_id').references('authors', 'id');
    });
  }

  @override
  down(Schema schema) {
    schema.drop('books');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class BookQuery extends Query<Book, BookQueryWhere> {
  BookQuery() {
    leftJoin('authors', 'author_id', 'id',
        additionalFields: const ['name', 'created_at', 'updated_at']);
    leftJoin('authors', 'partner_author_id', 'id',
        additionalFields: const ['name', 'created_at', 'updated_at']);
  }

  @override
  final BookQueryValues values = new BookQueryValues();

  @override
  final BookQueryWhere where = new BookQueryWhere();

  @override
  get tableName {
    return 'books';
  }

  @override
  get fields {
    return const [
      'id',
      'author_id',
      'partner_author_id',
      'name',
      'created_at',
      'updated_at'
    ];
  }

  @override
  BookQueryWhere newWhereClause() {
    return new BookQueryWhere();
  }

  static Book parseRow(List row) {
    if (row.every((x) => x == null)) return null;
    var model = new Book(
        id: row[0].toString(),
        name: (row[3] as String),
        createdAt: (row[4] as DateTime),
        updatedAt: (row[5] as DateTime));
    if (row.length > 6) {
      model =
          model.copyWith(author: AuthorQuery.parseRow(row.skip(6).toList()));
    }
    if (row.length > 10) {
      model = model.copyWith(
          partnerAuthor: AuthorQuery.parseRow(row.skip(10).toList()));
    }
    return model;
  }

  @override
  deserialize(List row) {
    return parseRow(row);
  }

  @override
  insert(executor) {
    return executor.transaction(() async {
      var result = await super.insert(executor);
      where.id.equals(int.parse(result.id));
      result = await getOne(executor);
      return result;
    });
  }
}

class BookQueryWhere extends QueryWhere {
  final NumericSqlExpressionBuilder<int> id =
      new NumericSqlExpressionBuilder<int>('id');

  final NumericSqlExpressionBuilder<int> authorId =
      new NumericSqlExpressionBuilder<int>('author_id');

  final NumericSqlExpressionBuilder<int> partnerAuthorId =
      new NumericSqlExpressionBuilder<int>('partner_author_id');

  final StringSqlExpressionBuilder name =
      new StringSqlExpressionBuilder('name');

  final DateTimeSqlExpressionBuilder createdAt =
      new DateTimeSqlExpressionBuilder('created_at');

  final DateTimeSqlExpressionBuilder updatedAt =
      new DateTimeSqlExpressionBuilder('updated_at');

  @override
  get expressionBuilders {
    return [id, authorId, partnerAuthorId, name, createdAt, updatedAt];
  }
}

class BookQueryValues extends MapQueryValues {
  int get id {
    return (values['id'] as int);
  }

  void set id(int value) => values['id'] = value;
  int get authorId {
    return (values['author_id'] as int);
  }

  void set authorId(int value) => values['author_id'] = value;
  int get partnerAuthorId {
    return (values['partner_author_id'] as int);
  }

  void set partnerAuthorId(int value) => values['partner_author_id'] = value;
  String get name {
    return (values['name'] as String);
  }

  void set name(String value) => values['name'] = value;
  DateTime get createdAt {
    return (values['created_at'] as DateTime);
  }

  void set createdAt(DateTime value) => values['created_at'] = value;
  DateTime get updatedAt {
    return (values['updated_at'] as DateTime);
  }

  void set updatedAt(DateTime value) => values['updated_at'] = value;
  void copyFrom(Book model) {
    values.addAll({
      'name': model.name,
      'created_at': model.createdAt,
      'updated_at': model.updatedAt
    });
    if (model.author != null) {
      values['author_id'] = int.parse(model.author.id);
    }
    if (model.partnerAuthor != null) {
      values['partner_author_id'] = int.parse(model.partnerAuthor.id);
    }
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Book extends _Book {
  Book(
      {this.id,
      this.author,
      this.partnerAuthor,
      this.name,
      this.createdAt,
      this.updatedAt});

  @override
  final String id;

  @override
  final Author author;

  @override
  final Author partnerAuthor;

  @override
  final String name;

  @override
  final DateTime createdAt;

  @override
  final DateTime updatedAt;

  Book copyWith(
      {String id,
      Author author,
      Author partnerAuthor,
      String name,
      DateTime createdAt,
      DateTime updatedAt}) {
    return new Book(
        id: id ?? this.id,
        author: author ?? this.author,
        partnerAuthor: partnerAuthor ?? this.partnerAuthor,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt);
  }

  bool operator ==(other) {
    return other is _Book &&
        other.id == id &&
        other.author == author &&
        other.partnerAuthor == partnerAuthor &&
        other.name == name &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return hashObjects([id, author, partnerAuthor, name, createdAt, updatedAt]);
  }

  Map<String, dynamic> toJson() {
    return BookSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

abstract class BookSerializer {
  static Book fromMap(Map map) {
    return new Book(
        id: map['id'] as String,
        author: map['author'] != null
            ? AuthorSerializer.fromMap(map['author'] as Map)
            : null,
        partnerAuthor: map['partner_author'] != null
            ? AuthorSerializer.fromMap(map['partner_author'] as Map)
            : null,
        name: map['name'] as String,
        createdAt: map['created_at'] != null
            ? (map['created_at'] is DateTime
                ? (map['created_at'] as DateTime)
                : DateTime.parse(map['created_at'].toString()))
            : null,
        updatedAt: map['updated_at'] != null
            ? (map['updated_at'] is DateTime
                ? (map['updated_at'] as DateTime)
                : DateTime.parse(map['updated_at'].toString()))
            : null);
  }

  static Map<String, dynamic> toMap(_Book model) {
    if (model == null) {
      return null;
    }
    return {
      'id': model.id,
      'author': AuthorSerializer.toMap(model.author),
      'partner_author': AuthorSerializer.toMap(model.partnerAuthor),
      'name': model.name,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String()
    };
  }
}

abstract class BookFields {
  static const List<String> allFields = const <String>[
    id,
    author,
    partnerAuthor,
    name,
    createdAt,
    updatedAt
  ];

  static const String id = 'id';

  static const String author = 'author';

  static const String partnerAuthor = 'partner_author';

  static const String name = 'name';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';
}
