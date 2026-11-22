import 'dart:io';

import 'package:test/test.dart';

import 'models/odd_alias.dart';

void main() {
  var model = OddAlias(
    quote: 'q',
    ref: '#/x',
    backslash: 'b',
    price: 3,
    counts: [1, 2],
  );
  var keys = {
    "it's": 'q',
    r'$ref': '#/x',
    r'back\slash': 'b',
    r"price $ and 'tax'": 3,
    'two words': [1, 2],
  };

  test('toMap writes the aliases as they are', () {
    expect(OddAliasSerializer.toMap(model), keys);
  });

  test('fromMap reads them back', () {
    expect(OddAliasSerializer.fromMap(keys), model);
    expect(OddAliasSerializer.fromMap(model.toJson()), model);
  });

  test('the Fields constants are the aliases', () {
    expect(OddAliasFields.quote, "it's");
    expect(OddAliasFields.ref, r'$ref');
    expect(OddAliasFields.backslash, r'back\slash');
    expect(OddAliasFields.price, r"price $ and 'tax'");
  });

  test('a missing required field names its alias', () {
    expect(
      () => OddAliasSerializer.fromMap({}),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(r"price $ and 'tax'"),
        ),
      ),
    );
    expect(
      () => OddAliasSerializer.toMap(OddAlias(price: null)),
      throwsA(isA<FormatException>()),
    );
  });

  test('the JSON Schema has the aliases as its properties', () {
    var properties = OddAliasSerializer.jsonSchema['properties'] as Map;
    expect(properties.keys.toSet(), keys.keys.toSet());
  });

  test('the TypeScript definition quotes what is not an identifier', () {
    var ts = File('test/models/odd_alias.d.ts').readAsStringSync();
    expect(ts, contains(r'$ref?: string;'));
    expect(ts, contains('"it\'s"?: string;'));
    expect(ts, contains(r'"back\\slash"?: string;'));
    expect(ts, contains(r'''"price $ and 'tax'": number;'''));
    expect(ts, contains('"two words"?: number[];'));
  });
}
