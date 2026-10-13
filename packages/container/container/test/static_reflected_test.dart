import 'package:angel3_container/angel3_container.dart';
import 'package:test/test.dart';

class Config {
  final String name;
  Config([this.name = 'default']);
}

class Logger {}

class Greeter {
  final Config config;
  final Logger? log;
  final int retries;

  Greeter(this.config, {this.log, this.retries = 3});
}

abstract class Shape {}

// What angel3_container_generator generates for the classes above.
final data = ReflectionData(
  types: {
    Config: StaticReflectedClass(
      'Config',
      Config,
      parameters: [
        ReflectedParameter(
          'name',
          const [],
          StaticReflectedType('String', String),
          false,
          false,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Config(p.isNotEmpty ? p[0] : 'default'),
    ),
    Logger: StaticReflectedClass('Logger', Logger, create: (p, n) => Logger()),
    Greeter: StaticReflectedClass(
      'Greeter',
      Greeter,
      parameters: [
        ReflectedParameter(
          'config',
          const [],
          StaticReflectedType('Config', Config),
          true,
          false,
        ),
        ReflectedParameter(
          'log',
          const [],
          StaticReflectedType('Logger', Logger),
          false,
          true,
        ),
        ReflectedParameter(
          'retries',
          const [],
          StaticReflectedType('int', int),
          false,
          true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Greeter(
        p[0],
        log: n.containsKey('log') ? n['log'] : null,
        retries: n.containsKey('retries') ? n['retries'] : 3,
      ),
    ),
    Shape: StaticReflectedClass('Shape', Shape),
  },
);

void main() {
  late Container container;

  setUp(() => container = Container(StaticReflector.combine([data])));

  test('constructs a class and its dependencies', () {
    var greeter = container.make<Greeter>();
    expect(greeter.config.name, 'default');
    expect(greeter.log, isA<Logger>());
    expect(greeter.retries, 3);
  });

  test('uses registered values, and keeps defaults otherwise', () {
    container.registerSingleton(Config('registered'));
    container.registerSingleton<int>(5);
    var greeter = container.make<Greeter>();
    expect(greeter.config.name, 'registered');
    expect(greeter.retries, 5);
  });

  test('an abstract class cannot be made', () {
    expect(() => container.make<Shape>(), throwsA(isA<ReflectionException>()));
  });

  test('a type without data cannot be made', () {
    expect(
      () => container.make<DateTime>(),
      throwsA(predicate(Container.isUnconstructible)),
    );
  });

  test('combine merges the data of several libraries', () {
    var more = ReflectionData(
      types: {DateTime: StaticReflectedType('DateTime', DateTime)},
    );
    var reflector = StaticReflector.combine([data, more]);
    expect(reflector.reflectType(Greeter)!.name, 'Greeter');
    expect(reflector.reflectType(DateTime)!.name, 'DateTime');
  });
}
