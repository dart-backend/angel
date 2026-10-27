import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';
import 'package:jael3/jael3.dart' as jael;
import 'package:test/test.dart';

/// Counts the calls of its `toJson()`.
class Counted {
  static int calls = 0;

  Map<String, dynamic> toJson() {
    calls++;
    return {'a': 1, 'b': 2, 'c': 3};
  }
}

/// Whose `toJson()` fails of a member of `null`.
class Broken {
  Map<String, dynamic> toJson() => {'a': (null as dynamic).nested};
}

/// Whose `toJson` takes an argument, so is not the JSON of the value.
class Shaped {
  Map<String, dynamic> toJson(bool full) => {'a': 1};
}

class User {
  final String name;
  final List<String> tags;

  const User(this.name, this.tags);

  String greet() => 'Hi, $name';

  Map<String, dynamic> toJson() => {'name': name, 'tags': tags, 'greet': greet};
}

jael.Document parse(String template) => jael.parseDocument(
  template,
  sourceUrl: 'test.jael',
  onError: (e) => throw e,
)!;

String render(
  String template,
  Map<String, dynamic> values, {
  bool strictResolution = true,
  jael.MemberResolver? memberResolver,
  SymbolTable? scope,
}) {
  var buf = CodeBuffer(space: '', newline: '');
  const jael.Renderer().render(
    parse(template),
    buf,
    scope ?? SymbolTable(values: values),
    strictResolution: strictResolution,
    memberResolver: memberResolver,
  );
  return buf.toString();
}

void main() {
  test('the same scope is rendered again', () {
    var scope = SymbolTable<dynamic>(values: {'n': 1});
    expect(render('<p>{{ n }}</p>', {}, scope: scope), '<p>1</p>');
    expect(render('<p>{{ n }}</p>', {}, scope: scope), '<p>1</p>');
  });

  group('toJson()', () {
    test('is called once for the members of a value in a render', () {
      Counted.calls = 0;
      expect(
        render('<p>{{ c.a }}{{ c.b }}{{ c.c }}</p>', {'c': Counted()}),
        '<p>123</p>',
      );
      expect(Counted.calls, 1);
    });

    test('of a member of null in it fails as that', () {
      expect(
        () => render('<p>{{ b.a }}</p>', {'b': Broken()}),
        throwsA(
          isA<NoSuchMethodError>().having(
            (e) => '$e',
            'message',
            contains('nested'),
          ),
        ),
      );
    });

    test('of an argument is none', () {
      expect(
        () => render('<p>{{ s.a }}</p>', {'s': Shaped()}),
        throwsNoSuchMethodError,
      );
    });
  });

  group('?.', () {
    for (var (template, expected) in [
      ('<p>{{ user?.name.length }}</p>', '4'),
      ('<p>{{ user?.greet() }}</p>', 'Hi, Anne'),
      ('<p>{{ user?.tags[1] }}</p>', 'b'),
      ('<p>{{ user?.greet().length }}</p>', '8'),
    ]) {
      test('of a null makes $template null', () {
        expect(render(template, {'user': null}), '<p></p>');
      });

      test('of a value reads $template', () {
        expect(
          render(template, {
            'user': const User('Anne', ['a', 'b']),
          }),
          '<p>$expected</p>',
        );
      });
    }
  });

  group('operators', () {
    test('%', () {
      expect(render('<p>{{ 7 % 3 }}</p>', {}), '<p>1</p>');
    });

    test('&& and ||', () {
      expect(
        render('<p>{{ t && f }} {{ t || f }} {{ f || t && t }}</p>', {
          't': true,
          'f': false,
        }),
        '<p>false true true</p>',
      );
    });

    test('&& and || compute the right only if needed', () {
      // Of a name that does not exist, which would throw.
      expect(
        render('<p>{{ f && missing }} {{ t || missing }}</p>', {
          't': true,
          'f': false,
        }),
        '<p>false true</p>',
      );
    });

    test('&& takes only true as true without strictResolution', () {
      expect(
        render('<p>{{ 1 && t }}</p>', {'t': true}, strictResolution: false),
        '<p>false</p>',
      );
    });

    test('= is no operator', () {
      expect(() => render('<p>{{ a = 1 }}</p>', {'a': 0}), throwsA(anything));
    });
  });

  test('the span of a pair of a map literal has its key', () {
    var p = parse('<p>{{ {a: 1} }}</p>').root;
    var map =
        (p.children.whereType<jael.Interpolation>().single.expression
            as jael.MapLiteral);
    expect(map.pairs.single.span.text, 'a: 1');
  });

  test('a map literal of key-value pairs', () {
    expect(
      render("<p>{{ {'a': 1, k: n + 1}['k2'] }}</p>", {'k': 'k2', 'n': 1}),
      '<p>2</p>',
    );
  });

  test('a call with a named argument', () {
    String pad(String s, {int width = 0}) => s.padLeft(width, '-');
    expect(
      render("<p>{{ pad('x', width: 3) }}</p>", {'pad': pad}),
      '<p>--x</p>',
    );
  });

  group('without strictResolution', () {
    test('an unknown member is null', () {
      expect(
        render('<p>{{ user.age }}</p>', {
          'user': const User('Anne', []),
        }, strictResolution: false),
        '<p></p>',
      );
    });

    test('a member of null is null', () {
      expect(
        render('<p>{{ user.name }}</p>', {
          'user': null,
        }, strictResolution: false),
        '<p></p>',
      );
    });

    test('with it, an unknown member throws', () {
      expect(
        () => render('<p>{{ user.age }}</p>', {'user': const User('Anne', [])}),
        throwsNoSuchMethodError,
      );
    });
  });

  test('the memberResolver reaches for-each and custom elements', () {
    var resolved = <String>[];
    Object? resolver(Object? target, String name) {
      if (target is! Counted) return jael.noMember;
      resolved.add(name);
      return name.toUpperCase();
    }

    expect(
      render(
        '<div><element name="item"><i>{{ c.x }}</i></element>'
        '<b for-each=items as="c">{{ c.y }}</b><item /></div>',
        {
          'items': [Counted()],
          'c': Counted(),
        },
        memberResolver: resolver,
      ),
      contains('Y'),
    );
    expect(resolved, containsAll(['x', 'y']));
  });

  test('a synthetic identifier has a span of its name', () {
    expect(jael.SyntheticIdentifier('item').span.text, 'item');
  });
}
