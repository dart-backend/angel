import 'package:angel3_container/angel3_container.dart';
import 'package:test/test.dart';

void main() {
  test('returns the same instance', () {
    var container = Container(const EmptyReflector())
      ..registerLazySingleton<Dummy>((_) => Dummy('a'));

    var first = container.make<Dummy>();
    expect(container.make<Dummy>(), first);
  });

  test('gives each child container its own instance, made with it', () {
    var root = Container(const EmptyReflector())
      ..registerLazySingleton<Dummy>((c) => Dummy('${c.isRoot}'));

    var child = root.createChild();
    var first = child.make<Dummy>();
    expect(first.s, 'false');
    expect(child.make<Dummy>(), same(first));
    expect(root.createChild().make<Dummy>(), isNot(same(first)));
  });
}

class Dummy {
  final String s;

  Dummy(this.s);
}
