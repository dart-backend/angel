import 'dart:collection';

import 'package:angel3_container/angel3_container.dart';
import 'package:test/test.dart';

import 'fixtures/services.dart';

/// `Container.make` with the reflection data generated for
/// `fixtures/services.dart` (regenerate it with `dart run build_runner build`).
void main() {
  late Container container;

  setUp(() {
    container = Container(StaticReflector.combine([servicesReflection]));
  });

  test('only @injectable classes are described', () {
    expect(servicesReflection.types.keys, [
      Config,
      Logger,
      Greeter,
      Mailer,
      Clock,
      Shape,
      Callbacks,
      Pay$Pal,
      Sub,
      Limits,
      Labels,
      Retrying,
    ]);
  });

  test('constructs a class and its dependencies, keeping defaults', () {
    var greeter = container.make<Greeter>();
    expect(greeter.config.name, 'default');
    expect(greeter.log, isA<Logger>());
    expect(greeter.retries, 3, reason: 'a private constant default');
    expect(greeter.queue, isNull, reason: 'nothing is registered for it');
  });

  test('uses registered values, including for a prefixed generic type', () {
    var queue = Queue<int>();
    container
      ..registerSingleton(Config('registered'))
      ..registerSingleton<int>(5)
      ..registerSingleton<Queue<int>>(queue);
    var greeter = container.make<Greeter>();
    expect(greeter.config.name, 'registered');
    expect(greeter.retries, 5);
    expect(greeter.queue, same(queue));
  });

  test('passes required named parameters', () {
    expect(container.make<Mailer>().config.name, 'default');
  });

  test('calls the factory constructor of an abstract class', () {
    expect(container.make<Clock>().now(), isA<DateTime>());
  });

  test('an abstract class without a factory constructor cannot be made', () {
    expect(() => container.make<Shape>(), throwsA(isA<ReflectionException>()));
  });

  test('function, record and typedef types are described and left out', () {
    var callbacks = container.make<Callbacks>();
    expect([
      callbacks.onQueue,
      callbacks.pair,
      callbacks.single,
      callbacks.handler,
    ], everyElement(isNull));
  });

  test(r'names with $ are written correctly', () {
    expect(container.make<Pay$Pal>().a$b, 1);
    var reflected = servicesReflection.types[Pay$Pal] as ReflectedClass;
    expect(reflected.name, r'Pay$Pal');
    expect(reflected.constructors.single.parameters.single.name, r'a$b');
  });

  test("a super. parameter gets its type with this library's prefix", () {
    var ids = HashSet<int>();
    container.registerSingleton<HashSet<int>>(ids);
    expect(container.make<Sub>().ids, same(ids));
  });

  test('a default that names a static member of the class applies', () {
    expect(container.make<Limits>().max, Limits.defaultMax);
  });

  test('an implicitly const default stays the same const value', () {
    var a = container.make<Labels>().labels, b = container.make<Labels>().labels;
    expect(a, isEmpty);
    expect(a, same(b));
    expect(() => a.add('x'), throwsUnsupportedError);
  });

  test('a super. parameter keeps the default it inherits', () {
    expect(container.make<Retrying>().retries, 5);
  });

  test('a registered value replaces a default', () {
    container.registerSingleton<int>(42);
    expect(container.make<Limits>().max, 42);
    expect(container.make<Retrying>().retries, 42);
  });

  test('a class without reflection data cannot be made', () {
    expect(
      () => container.make<NotInjectable>(),
      throwsA(predicate(Container.isUnconstructible)),
    );
  });
}
