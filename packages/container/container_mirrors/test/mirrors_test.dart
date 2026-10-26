import 'dart:async';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_container_mirrors/angel3_container_mirrors.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  testReflector(const MirrorsReflector());

  test('supertypes are the superclasses, nearest first, without Object', () {
    expect(const MirrorsReflector().reflectClass(_Leaf).supertypes, [
      _Middle,
      _Root,
    ]);
    expect(const MirrorsReflector().reflectClass(_Root).supertypes, isEmpty);
  });

  test('futureOf', () {
    var r = MirrorsReflector();
    var fStr = r.reflectFutureOf(String);
    expect(fStr.reflectedType.toString(), 'Future<String>');
    // expect(fStr.reflectedType, Future<String>.value(null).runtimeType);
  });

  test('concrete future make', () async {
    var c = Container(MirrorsReflector());
    c.registerFactory<Future<String>>((_) async => 'hey');
    var fStr = c.reflector.reflectFutureOf(String);
    var s1 = await c.make(fStr.reflectedType);
    var s2 = await c.makeAsync(String);
    print([s1, s2]);
    expect(s1, s2);
  });
}

class _Root {}

class _Middle extends _Root {}

class _Leaf extends _Middle {}
