import "package:angel3_merge_map/angel3_merge_map.dart";
import "package:test/test.dart";

void main() {
  test('can merge two simple maps', () {
    Map merged = mergeMap([
      {'hello': 'world'},
      {'hello': 'dolly'}
    ]);
    expect(merged['hello'], equals('dolly'));
  });

  test("the last map's values supersede those of prior", () {
    Map merged = mergeMap([
      {'letter': 'a'},
      {'letter': 'b'},
      {'letter': 'c'}
    ]);
    expect(merged['letter'], equals('c'));
  });

  test("can merge two once-nested maps", () {
    Map map1 = {
      'hello': 'world',
      'foo': {'nested': false}
    };
    Map map2 = {
      'goodbye': 'sad life',
      'foo': {'nested': true, 'it': 'works'}
    };
    Map merged = mergeMap([map1, map2]);

    expect(merged['hello'], equals('world'));
    expect(merged['goodbye'], equals('sad life'));
    expect(merged['foo']['nested'], equals(true));
    expect(merged['foo']['it'], equals('works'));
  });

  test("once-nested map supersession", () {
    Map map1 = {
      'hello': 'world',
      'foo': {'nested': false}
    };
    Map map2 = {
      'goodbye': 'sad life',
      'foo': {'nested': true, 'it': 'works'}
    };
    Map map3 = {
      'foo': {'nested': 'supersession'}
    };

    Map merged = mergeMap([map1, map2, map3]);
    expect(merged['foo']['nested'], equals('supersession'));
  });

  test("can merge two twice-nested maps", () {
    Map map1 = {
      'a': {
        'b': {'c': 'd'}
      }
    };
    Map map2 = {
      'a': {
        'b': {'c': 'D', 'e': 'f'}
      }
    };
    Map merged = mergeMap([map1, map2]);

    expect(merged['a']['b']['c'], equals('D'));
    expect(merged['a']['b']['e'], equals('f'));
  });

  test("twice-nested map supersession", () {
    Map map1 = {
      'a': {
        'b': {'c': 'd'}
      }
    };
    Map map2 = {
      'a': {
        'b': {'c': 'D', 'e': 'f'}
      }
    };
    Map map3 = {
      'a': {
        'b': {'e': 'supersession'}
      }
    };
    Map merged = mergeMap([map1, map2, map3]);

    expect(merged['a']['b']['c'], equals('D'));
    expect(merged['a']['b']['e'], equals('supersession'));
  });
}
