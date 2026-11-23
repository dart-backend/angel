import 'dart:convert';
import 'dart:typed_data';

import 'package:json_schema/json_schema.dart';
import 'package:test/test.dart';

import 'models/book.dart';
import 'models/garage.dart';
import 'models/schema_edge.dart';
import 'models/with_enum.dart';

/// A validator of [name] of [schemas], as an OpenAPI document holds them.
JsonSchema validatorOf(
  Map<String, Map<String, dynamic>> schemas,
  String name,
) => JsonSchema.create({
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'components': {'schemas': schemas},
  r'$ref': '#/components/schemas/$name',
}, schemaVersion: SchemaVersion.draft2020_12);

/// Whether [value] is valid of [validator], once it is JSON.
bool valid(JsonSchema validator, Object? value) =>
    validator.validate(json.decode(json.encode(value))).isValid;

void main() {
  group('nested models', () {
    var schemas = <String, Map<String, dynamic>>{};
    GarageSerializer.addJsonSchemas(schemas);
    var garage = validatorOf(schemas, 'Garage');

    test('addJsonSchemas adds the model and those it holds', () {
      expect(schemas.keys.toSet(), {'Garage', 'Car'});
      expect(GarageSerializer.schemaName, 'Garage');
      expect(schemas['Car'], CarSerializer.jsonSchema);
    });

    test('a toMap is valid', () {
      var car = Car(make: 'Fiat');
      expect(valid(garage, GarageSerializer.toMap(Garage(main: car))), isTrue);
      expect(
        valid(
          garage,
          GarageSerializer.toMap(
            Garage(
              main: car,
              spare: Car(make: 'Seat'),
            ),
          ),
        ),
        isTrue,
      );
    });

    test('a required model must be given, and a model must be one', () {
      expect(valid(garage, {'spare': null}), isFalse);
      expect(
        valid(garage, {
          'main': {'make': 'Fiat'},
          'spare': 'Seat',
        }),
        isFalse,
      );
      expect(valid(garage, {'main': {}}), isFalse);
    });
  });

  group('fields', () {
    var schemas = <String, Map<String, dynamic>>{};
    AuthorSerializer.addJsonSchemas(schemas);
    var author = validatorOf(schemas, 'Author');

    test('a toMap of lists of models, dates and aliases is valid', () {
      var book = Book(
        id: '0',
        title: 'Deathly Hallows',
        pageCount: 759,
        notModels: [1.0, 3.0],
        camelCaseString: 'x',
        updatedAt: DateTime.now(),
      );
      var map = AuthorSerializer.toMap(
        Author(id: '1', name: 'J.K.', age: 51, books: [book], newestBook: book),
      );
      expect(valid(author, map), isTrue);
      expect(schemas.keys.toSet(), {'Author', 'Book'});
    });

    test('a required field is never null', () {
      expect(valid(author, {'name': null, 'age': 1, 'books': []}), isFalse);
      expect(valid(author, {'age': 1, 'books': []}), isFalse);
      expect(valid(author, {'name': 'J.K.', 'age': 1, 'books': []}), isTrue);
    });

    test('an excluded field is left out', () {
      var properties = AuthorSerializer.jsonSchema['properties'] as Map;
      expect(properties, isNot(contains('secret')));
      expect(properties, isNot(contains('obscured')));
    });
  });

  group('enums and bytes', () {
    var schemas = <String, Map<String, dynamic>>{};
    WithEnumSerializer.addJsonSchemas(schemas);
    var withEnum = validatorOf(schemas, 'WithEnum');

    test('a toMap is valid', () {
      var model = WithEnum(
        type: WithEnumType.c,
        imageBytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(valid(withEnum, WithEnumSerializer.toMap(model)), isTrue);
      expect(valid(withEnum, {'type': null}), isTrue);
    });

    test('an enum is one of its indexes', () {
      expect(valid(withEnum, {'type': 5}), isFalse);
      expect(valid(withEnum, {'type': 'c'}), isFalse);
      var type = (WithEnumSerializer.jsonSchema['properties'] as Map)['type'];
      expect(
        (type as Map)['description'],
        'The index of WithEnumType: a, b, c',
      );
    });

    test('bytes are base64 text', () {
      var bytes =
          (WithEnumSerializer.jsonSchema['properties'] as Map)['image_bytes'];
      expect((bytes as Map)['contentEncoding'], 'base64');
      expect(valid(withEnum, {'image_bytes': 7}), isFalse);
    });
  });

  group('other fields', () {
    var schemas = <String, Map<String, dynamic>>{};
    EdgeSerializer.addJsonSchemas(schemas);
    var edge = validatorOf(schemas, 'Edge');

    test(
      'a toMap of a map of models, a default and a custom field is valid',
      () {
        var model = Edge(
          odd: 'o',
          carsByName: {'fiat': Car(make: 'Fiat')},
          count: 4,
          custom: 'x',
          label: 'l',
        );
        expect(valid(edge, EdgeSerializer.toMap(model)), isTrue);
      },
    );

    test('of an alias, a field without a default is required', () {
      var properties = EdgeSerializer.jsonSchema['properties'] as Map;
      expect(properties, contains('Odd Name'));
      expect(properties, isNot(contains('hidden')));
      expect(EdgeSerializer.jsonSchema['required'], ['label']);
      expect(valid(edge, {'count': 1}), isFalse);
      expect(
        valid(edge, {
          'cars_by_name': {'fiat': 'not a car'},
          'label': 'l',
        }),
        isFalse,
      );
    });

    test('a custom serializer writes anything', () {
      expect((EdgeSerializer.jsonSchema['properties'] as Map)['custom'], {});
    });
  });

  test('of models that hold each other', () {
    var schemas = <String, Map<String, dynamic>>{};
    PersonSerializer.addJsonSchemas(schemas);
    expect(schemas.keys.toSet(), {'Person', 'Pet'});
    var person = validatorOf(schemas, 'Person');
    var map = PersonSerializer.toMap(
      Person(
        name: 'Ana',
        pet: Pet(
          name: 'Rex',
          owner: Person(name: 'Ana'),
        ),
      ),
    );
    expect(valid(person, map), isTrue);
  });

  test('a null map of models is written as null', () {
    var map = EdgeSerializer.toMap(Edge(count: 1, label: 'l'));
    expect(map['cars_by_name'], isNull);
  });

  test('of a model that holds its own class', () {
    var schemas = <String, Map<String, dynamic>>{};
    NodeSerializer.addJsonSchemas(schemas);
    expect(schemas.keys, ['Node']);
    var node = validatorOf(schemas, 'Node');
    var tree = Node(
      name: 'root',
      children: [Node(name: 'leaf', children: [])],
    );
    expect(valid(node, NodeSerializer.toMap(tree)), isTrue);
    expect(
      valid(node, {
        'children': [
          {'name': 1},
        ],
      }),
      isFalse,
    );
  });
}
