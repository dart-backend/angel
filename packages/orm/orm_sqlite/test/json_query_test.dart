import 'package:test/test.dart';

import 'common.dart';
import 'models/has_map.dart';

const value = {
  'foo': 'bar',
  'n': 3,
  'x': 2.5,
  'ok': true,
  'none': null,
  'nested': {'a': 'b'},
  "it's": 'quoted',
};

const list = ['1', 2, 3.0];

/// Queries of JSON columns, of `Map` and `List` fields, and of their
/// properties, in SQLite's JSON functions.
void main() {
  for (var backend in backends) {
    group(backend.name, () {
      late TestDatabase db;

      setUp(() async {
        db = await backend.open();
        await (HasMapQuery()
              ..values.value = value
              ..values.list = list)
            .insert(db.executor);
        await (HasMapQuery()
              ..values.value = {'foo': 'baz', 'n': 'three'}
              ..values.list = ['10'])
            .insert(db.executor);
      });
      tearDown(() => db.close());

      Future<List<HasMap>> get(void Function(HasMapQueryWhere where) where) {
        var query = HasMapQuery();
        where(query.where!);
        return query.get(db.executor);
      }

      // Of its fields, deeply: `HasMap ==` compares a nested map by identity.
      var first = [
        isA<HasMap>()
            .having((m) => m.value, 'value', value)
            .having((m) => m.list, 'list', list),
      ];

      test('a row of JSON is read back', () async {
        expect(await get((w) => w.value['foo'].asString?.equals('bar')), first);
      });

      test('map equals', () async {
        expect(await get((w) => w.value.equals(value)), first);
        expect(await get((w) => w.value.equals({'foo': 'qux'})), isEmpty);
      });

      test('list equals', () async {
        expect(await get((w) => w.list.equals(list)), first);
        expect(await get((w) => w.list.equals(['1', 2])), isEmpty);
      });

      test('a property as a string', () async {
        expect(await get((w) => w.value['foo'].asString?.equals('bar')), first);
        expect(
          await get((w) => w.value['foo'].asString?.equals('qux')),
          isEmpty,
        );
      });

      test('a property as a number, of which text is none', () async {
        expect(await get((w) => w.value['n'].asInt?.equals(3)), first);
        expect(await get((w) => w.value['x'].asDouble?.greaterThan(2)), first);
        expect(await get((w) => w.value['n'].asInt?.greaterThan(0)), first);
      });

      test('a property as a boolean', () async {
        expect(await get((w) => w.value['ok'].asBool?.isTrue), first);
        expect(await get((w) => w.value['ok'].asBool?.isFalse), isEmpty);
        expect(await get((w) => w.value['foo'].asBool?.isTrue), isEmpty);
      });

      test('a property that is missing or null is NULL', () async {
        expect(await get((w) => w.value['none'].isNull), hasLength(2));
        expect(await get((w) => w.value['x'].isNotNull), first);
        expect(await get((w) => w.value.containsKey('ok')), first);
      });

      test('a property of a property', () async {
        expect(
          await get((w) => w.value['nested'].asMap?['a'].asString?.equals('b')),
          first,
        );
        expect(
          await get((w) => w.value['nested'].asMap?.equals({'a': 'b'})),
          first,
        );
      });

      test('an index of a list', () async {
        expect(await get((w) => w.list[0].asString?.equals('1')), first);
        expect(await get((w) => w.list[1].asInt?.equals(2)), first);
        expect(await get((w) => w.list[1].asInt?.equals(3)), isEmpty);
      });

      test("a key with a ' is escaped", () async {
        expect(
          await get((w) => w.value["it's"].asString?.equals('quoted')),
          first,
        );
      });

      test('a key with a " cannot be queried', () {
        expect(
          () => get((w) => w.value['a"b'].asString?.equals('x')),
          throwsArgumentError,
        );
      });

      test('contains is not supported', () {
        expect(
          () => get((w) => w.value.containsPair('foo', 'bar')),
          throwsUnsupportedError,
        );
      });

      test('a property as a date is not supported', () {
        expect(
          () => get(
            (w) => w.value['foo'].asDateTime?.equals(DateTime.utc(2024)),
          ),
          throwsUnsupportedError,
        );
      });
    });
  }
}
