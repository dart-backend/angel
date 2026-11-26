import 'dart:math';

import 'package:angel3_route/angel3_route.dart';
import 'package:test/test.dart';

void main() {
  test('evicts the least recently used entry', () {
    var map = LruMap<String, int>(2)
      ..['a'] = 1
      ..['b'] = 2;
    expect(map['a'], 1); // a is now the most recently used
    map['c'] = 3; // evicts b
    expect(map.keys, ['a', 'c']);
    expect(map.containsKey('b'), isFalse);
  });

  test('setting an entry makes it the most recently used', () {
    var map = LruMap<String, int>(2)
      ..['a'] = 1
      ..['b'] = 2
      // Replaced, not added.
      ..['a'] = 10
      ..['c'] = 3; // evicts b
    expect(map, {'a': 10, 'c': 3});
    expect(map.keys, ['a', 'c']);
  });

  test('containsKey and listing the keys do not change the order', () {
    var map = LruMap<String, int>(2)
      ..['a'] = 1
      ..['b'] = 2;
    expect(map.containsKey('a'), isTrue);
    expect(map.keys.toList(), ['a', 'b']);
    map['c'] = 3;
    expect(map.keys, ['b', 'c']);
  });

  test('a smaller maxSize evicts the least recently used at once', () {
    var map = LruMap<int, int>(5);
    for (var i = 0; i < 5; i++) {
      map[i] = i;
    }
    map.maxSize = 2;
    expect(map.keys, [3, 4]);
  });

  test('a maxSize of 0 holds nothing', () {
    var map = LruMap<String, int>(0)..['a'] = 1;
    expect(map, isEmpty);
    expect(map['a'], isNull);
  });

  test('remove and clear', () {
    var map = LruMap<String, int>(3)
      ..['a'] = 1
      ..['b'] = 2
      ..['c'] = 3;
    expect(map.remove('b'), 2);
    expect(map.remove('x'), isNull);
    expect(map.keys, ['a', 'c']);
    map['d'] = 4;
    expect(map.keys, ['a', 'c', 'd']);
    map.clear();
    expect(map, isEmpty);
    map['e'] = 5;
    expect(map.keys, ['e']);
  });

  test('behaves as a list kept in order of use', () {
    var random = Random(2);
    var map = LruMap<int, int>(8);
    // The keys, least recently used first, and their values.
    var order = <int>[];
    var values = <int, int>{};

    for (var i = 0; i < 20000; i++) {
      var key = random.nextInt(20);
      switch (random.nextInt(4)) {
        case 0:
          expect(map[key], values[key]);
          if (order.remove(key)) order.add(key);
        case 1:
          expect(map.remove(key), values.remove(key));
          order.remove(key);
        default:
          map[key] = i;
          values[key] = i;
          order
            ..remove(key)
            ..add(key);
          if (order.length > 8) values.remove(order.removeAt(0));
      }
      expect(map.keys, order);
      expect(map.length, order.length);
    }
  });
}
