import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';
import 'package:jael3/jael3.dart' as jael;
import 'package:test/test.dart';

class Pokemon {
  final String name;
  final String type;

  const Pokemon(this.name, this.type);
}

/// Whose members, of no resolver, are those of its JSON.
class Trainer {
  final String name;

  const Trainer(this.name);

  Map<String, dynamic> toJson() => {'name': name, 'level': 5};
}

String render(
  String template,
  Map<String, dynamic> values, {
  jael.MemberResolver? memberResolver,
}) {
  var buf = CodeBuffer();
  var document = jael.parseDocument(
    template,
    sourceUrl: 'test.jael',
    onError: (e) => throw e,
  )!;
  const jael.Renderer().render(
    document,
    buf,
    SymbolTable(values: values),
    memberResolver: memberResolver,
  );
  return buf.toString().trim();
}

void main() {
  test('a key of a map', () {
    expect(
      render('<p>{{ user.name }}</p>', {
        'user': {'name': 'Ann'},
      }),
      '<p>\n  Ann\n</p>',
    );
  });

  test('a key of a map before a member of Map', () {
    expect(
      render('<p>{{ m.length }} {{ m.keys.length }}</p>', {
        'm': {'length': 'long', 'a': 1},
      }),
      '<p>\n  long 2\n</p>',
    );
  });

  test('the members of core types', () {
    expect(
      render(
        '<p>{{ s.toUpperCase() }} {{ s.length }} {{ list.first }} '
        '{{ list.join("-") }} {{ n.toStringAsFixed(1) }} {{ d.year }} '
        '{{ i.isEven }}</p>',
        {
          's': 'abc',
          'list': [1, 2],
          'n': 2.25,
          'd': DateTime(2020, 1, 2),
          'i': 4,
        },
      ),
      '<p>\n  ABC 3 1 1-2 2.3 2020 true\n</p>',
    );
  });

  test('a member of the resolver', () {
    expect(
      render(
        '<p>{{ p.name }} {{ p.type }}</p>',
        {'p': const Pokemon('Pikachu', 'Electric')},
        memberResolver: (target, name) => switch ((target, name)) {
          (Pokemon p, 'name') => p.name.toUpperCase(),
          (Pokemon p, 'type') => p.type,
          _ => jael.noMember,
        },
      ),
      '<p>\n  PIKACHU Electric\n</p>',
    );
  });

  test('a getter of a class, without a resolver or JSON, is none', () {
    expect(
      () => render('<p>{{ p.name }}</p>', {
        'p': const Pokemon('Mew', 'Psychic'),
      }),
      throwsNoSuchMethodError,
    );
  });

  test('a key of the JSON of a value', () {
    expect(
      render('<p>{{ t.level }}</p>', {'t': const Trainer('Ash')}),
      '<p>\n  5\n</p>',
    );
  });

  test('throws of a member no way has', () {
    expect(
      () => render('<p>{{ t.age }}</p>', {'t': const Trainer('Ash')}),
      throwsNoSuchMethodError,
    );
  });

  test('"new" is a name', () {
    expect(render('<p>{{ new }}</p>', {'new': 'fresh'}), '<p>\n  fresh\n</p>');
  });
}
