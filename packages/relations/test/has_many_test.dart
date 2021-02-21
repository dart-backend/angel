import 'package:angel_framework/angel_framework.dart';
//import 'package:angel_relations/angel_relations.dart' as relations;
import 'package:angel_seeder/angel_seeder.dart';
import 'package:test/test.dart';
import 'common.dart';

main() {
  Angel app;

  setUp(() async {
    app = Angel()..use('/authors', MapService())..use('/books', MapService());

    await app.configure(seed(
        'authors',
        SeederConfiguration<Map>(
            count: 10,
            template: {'name': (Faker faker) => faker.person.name()},
            callback: (Map author, seed) {
              return seed(
                  'books',
                  SeederConfiguration(delete: false, count: 10, template: {
                    'authorId': author['id'],
                    'title': (Faker faker) =>
                        'I love to eat ${faker.food.dish()}'
                  }));
            })));

    // TODO: Missing afterAll method
    //  app
    //      .findService('authors')
    //      .afterAll(relations.hasMany('books', foreignKey: 'authorId'));
  });

  test('index', () async {
    var authors = await app.findService('authors').index();
    print(authors);

    expect(authors, allOf(isList, isNotEmpty));

    for (Map author in authors) {
      expect(author.keys, contains('books'));

      List<Map> books = author['books'];

      for (var book in books) {
        expect(book['authorId'], equals(author['id']));
      }
    }
  });

  test('create', () async {
    var tolstoy = await app
        .findService('authors')
        .create(Author(name: 'Leo Tolstoy').toJson());

    print(tolstoy);
    expect(tolstoy.keys, contains('books'));
    expect(tolstoy['books'], allOf(isList, isEmpty));
  });
}
