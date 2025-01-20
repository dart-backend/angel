import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'common.dart';
import 'models/book.dart';

import 'util.dart';

void main() {
  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;
  Author? jkRowling;
  Author? jameson;
  Book? deathlyHallows;

  setUp(() async {
    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [AuthorMigration(), BookMigration()]);

    // Insert an author
    var query = AuthorQuery()..values.name = 'J.K. Rowling';
    jkRowling = (await query.insert(executor)).value;

    query.values.name = 'J.K. Jameson';
    jameson = (await query.insert(executor)).value;

    // And a book
    var bookQuery = BookQuery();
    bookQuery.values
      ..authorId = jkRowling?.idAsInt ?? 0
      ..partnerAuthorId = jameson?.idAsInt ?? 0
      ..name = 'Deathly Hallows';

    deathlyHallows = (await bookQuery.insert(executor)).value;
  });

  tearDown(() async => await dropTables(runner));

  group('selects', () {
    test('select all', () async {
      var query = BookQuery();
      var books = await query.get(executor);
      expect(books, hasLength(1));

      var book = books.first;
      //print(book.toJson());
      expect(book.id, deathlyHallows!.id);
      expect(book.name, deathlyHallows!.name);

      var author = book.author!;
      //print(AuthorSerializer.toMap(author));
      expect(author.id, jkRowling!.id);
      expect(author.name, jkRowling!.name);
    });

    test('select one', () async {
      var query = BookQuery();
      query.where!.id.equals(int.parse(deathlyHallows!.id!));
      //print(query.compile({}));

      var bookOpt = await query.getOne(executor);
      expect(bookOpt.isPresent, true);
      bookOpt.ifPresent((book) {
        //print(book.toJson());
        expect(book.id, deathlyHallows!.id);
        expect(book.name, deathlyHallows!.name);

        var author = book.author!;
        //print(AuthorSerializer.toMap(author));
        expect(author.id, jkRowling!.id);
        expect(author.name, jkRowling!.name);
      });
    });

    test('where clause', () async {
      var query = BookQuery()
        ..where!.name.equals('Goblet of Fire')
        ..orWhere((w) => w.authorId.equals(int.parse(jkRowling!.id!)));
      //print(query.compile({}));

      var books = await query.get(executor);
      expect(books, hasLength(1));

      var book = books.first;
      //print(book.toJson());
      expect(book.id, deathlyHallows!.id);
      expect(book.name, deathlyHallows!.name);

      var author = book.author!;
      //print(AuthorSerializer.toMap(author));
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
      //print(query1.compile({}));

      var books = await query1.get(executor);
      expect(books, hasLength(1));

      var book = books.first;
      //print(book.toJson());
      expect(book.id, deathlyHallows!.id);
      expect(book.name, deathlyHallows!.name);

      var author = book.author!;
      //print(AuthorSerializer.toMap(author));
      expect(author.id, jkRowling!.id);
      expect(author.name, jkRowling!.name);
    });

    test('order by', () async {
      var query = AuthorQuery()..orderBy(AuthorFields.name, descending: true);
      var authors = await query.get(executor);
      expect(authors, [jkRowling, jameson]);
    });
  });

  test('insert sets relationship', () {
    expect(deathlyHallows!.author, jkRowling);
    //expect(deathlyHallows.author, isNotNull);
    //expect(deathlyHallows.author.name, rowling.name);
  });

  test('delete stream', () async {
    //printSeparator('Delete stream test');
    var query = BookQuery()..where!.name.equals(deathlyHallows!.name!);
    //print(query.compile({}, preamble: 'DELETE', withFields: false));
    var books = await query.delete(executor);
    expect(books, hasLength(1));

    var book = books.first;
    expect(book.id, deathlyHallows?.id);
    expect(book.author, isNotNull);
    expect(book.author!.name, jkRowling!.name);
  });

  test('update book', () async {
    var cloned = deathlyHallows!.copyWith(name: "Sorcerer's Stone");
    var query = BookQuery()
      ..where?.id.equals(int.parse(cloned.id!))
      ..values.copyFrom(cloned);
    var bookOpt = await (query.updateOne(executor));
    expect(bookOpt.isPresent, true);
    bookOpt.ifPresent((book) {
      //print(book.toJson());
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
      var query = BookQuery()..author.where!.name.equals('Billie Jean');
      expect(await query.get(executor), isEmpty);
    });

    test('returns values on true subquery', () async {
      printSeparator('True subquery test');
      var query = BookQuery()..author.where!.name.like('%Rowling%');
      expect(await query.get(executor), [deathlyHallows]);
    });
  });
}
