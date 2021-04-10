import 'package:json_god/json_god.dart' as god;
import 'package:test/test.dart';
import 'shared.dart';

main() {
  god.logger.onRecord.listen(printRecord);

  group('deserialization', () {
    test('deserialize primitives', testDeserializationOfPrimitives);

    test('deserialize maps', testDeserializationOfMaps);

    test('deserialize maps + reflection', testDeserializationOfMapsWithReflection);

    test('deserialize lists + reflection',
        testDeserializationOfListsAsWellAsViaReflection);

    test('deserialize with schema validation',
        testDeserializationWithSchemaValidation);
  });
}

testDeserializationOfPrimitives() {
  expect(god.deserialize('1'), equals(1));
  expect(god.deserialize('1.4'), equals(1.4));
  expect(god.deserialize('"Hi!"'), equals("Hi!"));
  expect(god.deserialize("true"), equals(true));
  expect(god.deserialize("null"), equals(null));
}

testDeserializationOfMaps() {
  String simpleJson =
      '{"hello":"world", "one": 1, "class": {"hello": "world"}}';
  String nestedJson =
      '{"foo": {"bar": "baz", "funny": {"how": "life", "seems": 2, "hate": "us sometimes"}}}';
  var simple = god.deserialize(simpleJson ) as Map;
  var nested = god.deserialize(nestedJson) as Map;

  expect(simple['hello'], equals('world'));
  expect(simple['one'], equals(1));
  expect(simple['class']['hello'], equals('world'));

  expect(nested['foo']['bar'], equals('baz'));
  expect(nested['foo']['funny']['how'], equals('life'));
  expect(nested['foo']['funny']['seems'], equals(2));
  expect(nested['foo']['funny']['hate'], equals('us sometimes'));
}

class Pokedex {
  Map<String, int>? pokemon;
}

testDeserializationOfMapsWithReflection() {
  var s = '{"pokemon": {"Bulbasaur": 1, "Deoxys": 382}}';
  var pokedex = god.deserialize(s, outputType: Pokedex) as Pokedex;
  expect(pokedex.pokemon, hasLength(2));
  expect(pokedex.pokemon!['Bulbasaur'], 1);
  expect(pokedex.pokemon!['Deoxys'], 382);
}

testDeserializationOfListsAsWellAsViaReflection() {
  String json = '''[
    {
      "hello": "world",
      "nested": []
    },
    {
      "hello": "dolly",
      "nested": [
        {
          "bar": "baz"
        },
        {
          "bar": "fight"
        }
      ]
    }
  ]
  ''';

  var list = god.deserialize(json, outputType: (<SampleClass>[]).runtimeType) as List<SampleClass>;
  SampleClass first = list[0];
  SampleClass second = list[1];

  expect(list.length, equals(2));
  expect(first.hello, equals("world"));
  expect(first.nested.length, equals(0));
  expect(second.hello, equals("dolly"));
  expect(second.nested.length, equals(2));

  SampleNestedClass firstNested = second.nested[0];
  SampleNestedClass secondNested = second.nested[1];

  expect(firstNested.bar, equals("baz"));
  expect(secondNested.bar, equals("fight"));
}

testDeserializationWithSchemaValidation() async {
  String babelRcJson =
      '{"presets":["es2015","stage-0"],"plugins":["add-module-exports"]}';

  var deserialized = god.deserialize(babelRcJson, outputType: BabelRc) as BabelRc;

  print(deserialized.presets.runtimeType);
  expect(deserialized.presets is List, equals(true));
  expect(deserialized.presets.length, equals(2));
  expect(deserialized.presets[0], equals('es2015'));
  expect(deserialized.presets[1], equals('stage-0'));
  expect(deserialized.plugins is List, equals(true));
  expect(deserialized.plugins.length, equals(1));
  expect(deserialized.plugins[0], equals('add-module-exports'));
}
