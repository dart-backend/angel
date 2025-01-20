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
abstract class _Book extends Model {
  String? author, title, description;

  /// The number of pages the book has.
  int? pageCount;

  List<double>? notModels;

  @SerializableField(alias: 'camelCase', isNullable: true)
  String? camelCaseString;
}

@Serializable(serializers: Serializers.all)
abstract class _Author extends Model {
  @SerializableField(isNullable: false)
  String? get name;

  String get customMethod => 'hey!';

  @SerializableField(
      isNullable: false, errorMessage: 'Custom message for missing `age`')
  int? get age;

  List<_Book> get books;

  /// The newest book.
  _Book? get newestBook;

  @SerializableField(exclude: true, isNullable: true)
  String? get secret;

  @SerializableField(exclude: true, canDeserialize: true, isNullable: true)
  String? get obscured;
}

@Serializable(serializers: Serializers.all)
abstract class _Library extends Model {
  Map<String, _Book> get collection;
}

@Serializable(serializers: Serializers.all)
abstract class _Bookmark extends Model {
  @SerializableField(exclude: true)
  final _Book book;

  List<int> get history;

  @SerializableField(isNullable: false)
  int? get page;

  String? get comment;

  _Bookmark(this.book);
}
