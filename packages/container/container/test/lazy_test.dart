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

  test('gives a child its own instance after the root made one', () {
    var root = Container(const EmptyReflector())
      ..registerLazySingleton<Dummy>((c) => Dummy('${c.isRoot}'));

    var rootInstance = root.make<Dummy>();
    expect(rootInstance.s, 'true');
    expect(root.make<Dummy>(), same(rootInstance));

    var child = root.createChild();
    var childInstance = child.make<Dummy>();
    expect(childInstance.s, 'false');
    expect(child.make<Dummy>(), same(childInstance));
    expect(root.make<Dummy>(), same(rootInstance));
  });

  test("shares a child's instance with its own children", () {
    var root = Container(const EmptyReflector())
      ..registerLazySingleton<Dummy>((c) => Dummy('${c.isRoot}'));

    var child = root.createChild();
    var first = child.make<Dummy>();
    expect(child.createChild().make<Dummy>(), same(first));
  });

  test('keeps a plain singleton shared with children', () {
    var root = Container(const EmptyReflector())
      ..registerSingleton<Dummy>(Dummy('a'));
    expect(root.createChild().make<Dummy>(), same(root.make<Dummy>()));
  });
}

class Dummy {
  final String s;

  Dummy(this.s);
}
