import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_container/mirrors.dart';
import 'package:test/test.dart';

void main() {
  late Container container;

  setUp(() {
    container = Container(const MirrorsReflector())..registerSingleton(Dep());
  });

  group('make', () {
    test('injects required named parameters', () {
      expect(container.make<NamedRequired>().dep, isA<Dep>());
    });

    test('injects optional named parameters', () {
      expect(container.make<NamedOptional>().dep, isA<Dep>());
    });

    test('leaves out an optional named parameter it cannot make', () {
      expect(container.make<NamedNullable>().prefix, isNull);
    });

    test('makes an unregistered named parameter it can construct', () {
      expect(container.make<NamedConstructible>().other, isA<Other>());
    });

    test('keeps the default of an unregistered parameter', () {
      expect(container.make<PositionalDefault>().retries, 3);
      expect(container.make<NamedDefault>().retries, 3);
    });

    test('injects a registered parameter instead of its default', () {
      container.registerSingleton<int>(5);
      expect(container.make<PositionalDefault>().retries, 5);
      expect(container.make<NamedDefault>().retries, 5);
    });

    test('leaves out later optional positionals after an omitted one', () {
      var made = container.make<Positionals>();
      expect(made.retries, 3);
      expect(made.dep, isNull);
    });
  });
}

class Dep {}

class NamedRequired {
  final Dep dep;
  NamedRequired({required this.dep});
}

class NamedOptional {
  final Dep? dep;
  NamedOptional({this.dep});
}

class PositionalDefault {
  final int retries;
  PositionalDefault([this.retries = 3]);
}

class NamedDefault {
  final int retries;
  NamedDefault({this.retries = 3});
}

class Positionals {
  final int retries;
  final Dep? dep;
  // `dep` is registered, but cannot be passed without `retries`.
  Positionals([this.retries = 3, this.dep]);
}

class NamedNullable {
  final String? prefix;
  NamedNullable({this.prefix});
}

class Other {}

class NamedConstructible {
  final Other other;
  NamedConstructible({required this.other});
}
