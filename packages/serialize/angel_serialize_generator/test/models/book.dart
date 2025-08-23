library;

import 'package:angel3_serialize/angel3_serialize.dart';
part 'book.g.dart';

@Serializable(
  serializers: Serializers.all,
  includeAnnotations: [
    pragma('hello'),
    SerializableField(alias: 'omg'),
  ],
)
abstract class BookEntity extends Model {
  String? author, title, description;

  /// The number of pages the book has.
  int? pageCount;

  List<double>? notModels;

  @SerializableField(alias: 'camelCase', isNullable: true)
  String? camelCaseString;
}

@Serializable(serializers: Serializers.all)
abstract class AuthorEntity extends Model {
  @SerializableField(isNullable: false)
  String? get name;

  String get customMethod => 'hey!';

  @SerializableField(
    isNullable: false,
    errorMessage: 'Custom message for missing `age`',
  )
  int? get age;

  List<BookEntity> get books;

  /// The newest book.
  BookEntity? get newestBook;

  @SerializableField(exclude: true, isNullable: true)
  String? get secret;

  @SerializableField(exclude: true, canDeserialize: true, isNullable: true)
  String? get obscured;
}

@Serializable(serializers: Serializers.all)
abstract class LibraryEntity extends Model {
  Map<String, BookEntity> get collection;
}

@Serializable(serializers: Serializers.all)
abstract class BookmarkEntity extends Model {
  @SerializableField(exclude: true)
  final BookEntity book;

  List<int> get history;

  @SerializableField(isNullable: false)
  int? get page;

  String? get comment;

  BookmarkEntity(this.book);
}
