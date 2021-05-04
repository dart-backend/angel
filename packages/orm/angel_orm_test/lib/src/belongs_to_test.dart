import 'dart:async';
import 'package:angel_orm/angel_orm.dart';
import 'package:test/test.dart';
import 'models/book.dart';
import 'package:optional/optional.dart';

import 'util.dart';

belongsToTests(FutureOr<QueryExecutor> Function() createExecutor,
    {FutureOr<void> Function(QueryExecutor)? close}) {
  late QueryExecutor executor;
  Author? jkRowling;
  Author? jameson;
  Book? deathlyHallows;
  close ??= (_) => null;

  setUp(() async {
    executor = await createExecutor();

    // Insert an author
    var query = AuthorQuery()..values.name = 'J.K. Rowling';
    jkRowling = (await query.insert(executor)).value;

    query.values.name = 'J.K. Jameson';
    jameson = (await query.insert(executor)).value;

    // And a book
    var bookQuery = BookQuery();
    bookQuery.values
      ..authorId = int.parse(jkRowling!.id!)
      ..partnerAuthorId = int.parse(jameson!.id!)
      ..name = 'Deathly Hallows';

    deathlyHallows = (await bookQuery.insert(executor)).value;
  });

  tearDown(() => close!(executor));

  group('selects', () {
    test('select all', () async {
      var query = BookQuery();
      List<Book> books = await query.get(executor);
      expect(books, hasLength(1));

      var book = books.first;
      print(book.toJson());
      expect(book.id, deathlyHallows!.id);
      expect(book.name, deathlyHallows!.name);

      var author = book.author!;
      print(AuthorSerializer.toMap(author));
      expect(author.id, jkRowling!.id);
      expect(author.name, jkRowling!.name);
    });

    test('select one', () async {
      var query = BookQuery();
      query.where!.id.equals(int.parse(deathlyHallows!.id!));
      print(query.compile(Set()));

      var book = await (query.getOne(executor) as FutureOr<Book>);
      print(book.toJson());
      expect(book.id, deathlyHallows!.id);
      expect(book.name, deathlyHallows!.name);

      var author = book.author!;
      print(AuthorSerializer.toMap(author));
      expect(author.id, jkRowling!.id);
      expect(author.name, jkRowling!.name);
    });

    test('where clause', () async {
      var query = BookQuery()
        ..where!.name.equals('Goblet of Fire')
        ..orWhere((w) => w.authorId.equals(int.parse(jkRowling!.id!)));
      print(query.compile(Set()));

      List<Book> books = await query.get(executor);
      expect(books, hasLength(1));

      var book = books.first;
      print(book.toJson());
      expect(book.id, deathlyHallows!.id);
      expect(book.name, deathlyHallows!.name);

      var author = book.author!;
      print(AuthorSerializer.toMap(author));
      expect(author.id, jkRowling!.id);
      expect(author.name, jkRowling!.name);
    });

    test('union', () async {
      var query1 = BookQuery()..where!.name.like('Deathly%');
      var query2 = BookQuery()..where!.authorId.equals(-1);
      var query3 = BookQuery()
        ..where!.name.isIn(['Goblet of Fire', 'Order of the Phoenix']);
      query1
        ..union(query2)
        ..unionAll(query3);
      print(query1.compile(Set()));

      List<Book> books = await query1.get(executor);
      expect(books, hasLength(1));

      var book = books.first;
      print(book.toJson());
      expect(book.id, deathlyHallows!.id);
      expect(book.name, deathlyHallows!.name);

      var author = book.author!;
      print(AuthorSerializer.toMap(author));
      expect(author.id, jkRowling!.id);
      expect(author.name, jkRowling!.name);
    });

    test('order by', () async {
      var query = AuthorQuery()..orderBy(AuthorFields.name, descending: true);
      List<Author> authors = await query.get(executor);
      expect(authors, [jkRowling, jameson]);
    });
  });

  test('insert sets relationship', () {
    expect(deathlyHallows!.author, jkRowling);
    //expect(deathlyHallows.author, isNotNull);
    //expect(deathlyHallows.author.name, rowling.name);
  });

  test('delete stream', () async {
    printSeparator('Delete stream test');
    var query = BookQuery()..where!.name.equals(deathlyHallows!.name!);
    print(query.compile(Set(), preamble: 'DELETE', withFields: false));
    List<Book>? books = await query.delete(executor);
    expect(books, hasLength(1));

    var book = books.first;
    expect(book.id, deathlyHallows!.id);
    expect(book.author, isNotNull);
    expect(book.author!.name, jkRowling!.name);
  });

  test('update book', () async {
    var cloned = deathlyHallows!.copyWith(name: "Sorcerer's Stone");
    var query = BookQuery()
      ..where!.id.equals(int.parse(cloned.id!))
      ..values.copyFrom(cloned);
    var bookOpt = await (query.updateOne(executor));
    bookOpt.ifPresent((book) {
      print(book.toJson());
      expect(book.name, cloned.name);
      expect(book.author, isNotNull);
      expect(book.author!.name, jkRowling!.name);
    });
  });

  group('joined subquery', () {
    // To verify that the joined subquery is correct,
    // we test both a query that return empty, and one
    // that should return correctly.
    test('returns empty on false subquery', () async {
      printSeparator('False subquery test');
      var query = BookQuery()..author!.where!.name.equals('Billie Jean');
      expect(await query.get(executor), isEmpty);
    });

    test('returns values on true subquery', () async {
      printSeparator('True subquery test');
      var query = BookQuery()..author!.where!.name.like('%Rowling%');
      expect(await query.get(executor), [deathlyHallows]);
    });
  });
}
