// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class BookMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('books', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
      table
          .declare('partner_author_id', ColumnType('int'))
          .references('authors', 'id');
      table.declare('author_id', ColumnType('int')).references('authors', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('books');
  }
}

class AuthorMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('authors', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255)
        ..defaultsTo('Tobe Osakwe')
        ..unique();
      table.varChar('publisher', length: 255);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('authors');
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Book extends EntityBook {
  Book({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.partnerAuthor,
    this.author,
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
  EntityAuthor? partnerAuthor;

  @override
  EntityAuthor? author;

  @override
  String? name;

  Book copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    EntityAuthor? partnerAuthor,
    EntityAuthor? author,
    String? name,
  }) {
    return Book(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      partnerAuthor: partnerAuthor ?? this.partnerAuthor,
      author: author ?? this.author,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(other) {
    return other is EntityBook &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.partnerAuthor == partnerAuthor &&
        other.author == author &&
        other.name == name;
  }

  @override
  int get hashCode {
    return hashObjects([id, createdAt, updatedAt, partnerAuthor, author, name]);
  }

  @override
  String toString() {
    return 'Book(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, partnerAuthor=$partnerAuthor, author=$author, name=$name)';
  }

  Map<String, dynamic> toJson() {
    return BookSerializer.toMap(this);
  }
}

@generatedSerializable
class Author extends EntityAuthor {
  Author({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.name = 'Tobe Osakwe',
    this.publisher,
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

  @override
  String? publisher;

  Author copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    String? publisher,
  }) {
    return Author(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      publisher: publisher ?? this.publisher,
    );
  }

  @override
  bool operator ==(other) {
    return other is EntityAuthor &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        other.publisher == publisher;
  }

  @override
  int get hashCode {
    return hashObjects([id, createdAt, updatedAt, name, publisher]);
  }

  @override
  String toString() {
    return 'Author(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, publisher=$publisher)';
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
      partnerAuthor: map['partner_author'] != null
          ? AuthorSerializer.fromMap(map['partner_author'] as Map)
          : null,
      author: map['author'] != null
          ? AuthorSerializer.fromMap(map['author'] as Map)
          : null,
      name: map['name'] as String?,
    );
  }

  static Map<String, dynamic> toMap(EntityBook? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'partner_author': AuthorSerializer.toMap(model.partnerAuthor),
      'author': AuthorSerializer.toMap(model.author),
      'name': model.name,
    };
  }
}

abstract class BookFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    partnerAuthor,
    author,
    name,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String partnerAuthor = 'partner_author';

  static const String author = 'author';

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
      name: map['name'] as String? ?? 'Tobe Osakwe',
      publisher: map['publisher'] as String?,
    );
  }

  static Map<String, dynamic> toMap(EntityAuthor? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'publisher': model.publisher,
    };
  }
}

abstract class AuthorFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    publisher,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String publisher = 'publisher';
}
