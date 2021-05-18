import 'package:angel3_merge_map/angel3_merge_map.dart';
import 'package:test/test.dart';

void main() {
  test('can merge two simple maps', () {
    var merged = mergeMap([
      {'hello': 'world'},
      {'hello': 'dolly'}
    ]);
    expect(merged['hello'], equals('dolly'));
  });

  test("the last map's values supersede those of prior", () {
    var merged = mergeMap([
      {'letter': 'a'},
      {'letter': 'b'},
      {'letter': 'c'}
    ]);
    expect(merged['letter'], equals('c'));
  });

  test('can merge two once-nested maps', () {
    // ignore: omit_local_variable_types
    Map map1 = {
      'hello': 'world',
      'foo': {'nested': false}
    };
    // ignore: omit_local_variable_types
    Map map2 = {
      'goodbye': 'sad life',
      'foo': {'nested': true, 'it': 'works'}
    };
    var merged = mergeMap([map1, map2]);

    expect(merged['hello'], equals('world'));
    expect(merged['goodbye'], equals('sad life'));
    expect(merged['foo']['nested'], equals(true));
    expect(merged['foo']['it'], equals('works'));
  });

  test('once-nested map supersession', () {
    // ignore: omit_local_variable_types
    Map map1 = {
      'hello': 'world',
      'foo': {'nested': false}
    };
    // ignore: omit_local_variable_types
    Map map2 = {
      'goodbye': 'sad life',
      'foo': {'nested': true, 'it': 'works'}
    };
    // ignore: omit_local_variable_types
    Map map3 = {
      'foo': {'nested': 'supersession'}
    };

    var merged = mergeMap([map1, map2, map3]);
    expect(merged['foo']['nested'], equals('supersession'));
  });

  test('can merge two twice-nested maps', () {
    // ignore: omit_local_variable_types
    Map map1 = {
      'a': {
        'b': {'c': 'd'}
      }
    };
    // ignore: omit_local_variable_types
    Map map2 = {
      'a': {
        'b': {'c': 'D', 'e': 'f'}
      }
    };
    var merged = mergeMap([map1, map2]);

    expect(merged['a']['b']['c'], equals('D'));
    expect(merged['a']['b']['e'], equals('f'));
  });

  test('twice-nested map supersession', () {
    // ignore: omit_local_variable_types
    Map map1 = {
      'a': {
        'b': {'c': 'd'}
      }
    };
    // ignore: omit_local_variable_types
    Map map2 = {
      'a': {
        'b': {'c': 'D', 'e': 'f'}
      }
    };
    // ignore: omit_local_variable_types
    Map map3 = {
      'a': {
        'b': {'e': 'supersession'}
      }
    };
    var merged = mergeMap([map1, map2, map3]);

    expect(merged['a']['b']['c'], equals('D'));
    expect(merged['a']['b']['e'], equals('supersession'));
  });
}
