//import 'package:dart2_constant/convert.dart';
import 'dart:convert';

import 'package:angel3_json_god/angel3_json_god.dart' as god;
import 'package:test/test.dart';
import 'shared.dart';

main() {
  god.logger.onRecord.listen(printRecord);

  group('serialization', () {
    test('serialize primitives', testSerializationOfPrimitives);

    test('serialize dates', testSerializationOfDates);

    test('serialize maps', testSerializationOfMaps);

    test('serialize lists', testSerializationOfLists);

    test('serialize via reflection', testSerializationViaReflection);

    test('serialize with schema validation',
        testSerializationWithSchemaValidation);
  });
}

testSerializationOfPrimitives() {
  expect(god.serialize(1), equals("1"));
  expect(god.serialize(1.4), equals("1.4"));
  expect(god.serialize("Hi!"), equals('"Hi!"'));
  expect(god.serialize(true), equals("true"));
  expect(god.serialize(null), equals("null"));
}

testSerializationOfDates() {
  DateTime date = DateTime.now();
  String s = god.serialize({'date': date});

  print(s);

  var deserialized = json.decode(s);
  expect(deserialized['date'], equals(date.toIso8601String()));
}

testSerializationOfMaps() {
  var simple = json.decode(god
      .serialize({'hello': 'world', 'one': 1, 'class': SampleClass('world')}));
  var nested = json.decode(god.serialize({
    'foo': {
      'bar': 'baz',
      'funny': {'how': 'life', 'seems': 2, 'hate': 'us sometimes'}
    }
  }));

  expect(simple['hello'], equals('world'));
  expect(simple['one'], equals(1));
  expect(simple['class']['hello'], equals('world'));

  expect(nested['foo']['bar'], equals('baz'));
  expect(nested['foo']['funny']['how'], equals('life'));
  expect(nested['foo']['funny']['seems'], equals(2));
  expect(nested['foo']['funny']['hate'], equals('us sometimes'));
}

testSerializationOfLists() {
  List pandorasBox = [
    1,
    "2",
    {"num": 3, "four": SampleClass('five')},
    SampleClass('six')..nested.add(SampleNestedClass('seven'))
  ];
  String s = god.serialize(pandorasBox);
  print(s);

  var deserialized = json.decode(s);

  expect(deserialized is List, equals(true));
  expect(deserialized.length, equals(4));
  expect(deserialized[0], equals(1));
  expect(deserialized[1], equals("2"));
  expect(deserialized[2] is Map, equals(true));
  expect(deserialized[2]['num'], equals(3));
  expect(deserialized[2]['four'] is Map, equals(true));
  expect(deserialized[2]['four']['hello'], equals('five'));
  expect(deserialized[3] is Map, equals(true));
  expect(deserialized[3]['hello'], equals('six'));
  expect(deserialized[3]['nested'] is List, equals(true));
  expect(deserialized[3]['nested'].length, equals(1));
  expect(deserialized[3]['nested'][0] is Map, equals(true));
  expect(deserialized[3]['nested'][0]['bar'], equals('seven'));
}

testSerializationViaReflection() {
  SampleClass sample = SampleClass('world');

  for (int i = 0; i < 3; i++) {
    sample.nested.add(SampleNestedClass('baz'));
  }

  String s = god.serialize(sample);
  print(s);

  var deserialized = json.decode(s);
  expect(deserialized['hello'], equals('world'));
  expect(deserialized['nested'] is List, equals(true));
  expect(deserialized['nested'].length == 3, equals(true));
  expect(deserialized['nested'][0]['bar'], equals('baz'));
  expect(deserialized['nested'][1]['bar'], equals('baz'));
  expect(deserialized['nested'][2]['bar'], equals('baz'));
}

testSerializationWithSchemaValidation() async {
  BabelRc babelRc =
      BabelRc(presets: ['es2015', 'stage-0'], plugins: ['add-module-exports']);

  String s = god.serialize(babelRc);
  print(s);

  var deserialized = json.decode(s);

  expect(deserialized['presets'] is List, equals(true));
  expect(deserialized['presets'].length, equals(2));
  expect(deserialized['presets'][0], equals('es2015'));
  expect(deserialized['presets'][1], equals('stage-0'));
  expect(deserialized['plugins'] is List, equals(true));
  expect(deserialized['plugins'].length, equals(1));
  expect(deserialized['plugins'][0], equals('add-module-exports'));

  //Map babelRc2 = {'presets': 'Hello, world!'};

  String json2 = god.serialize(babelRc);
  print(json2);
}
