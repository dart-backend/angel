import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_markdown/angel3_markdown.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:test/test.dart';

class Genus {
  final String name;

  Genus(this.name);

  Map<String, dynamic> toJson() => {'name': name};
}

class Species {
  final String name;
  final Genus genus;

  Species(this.name, this.genus);

  // Leaves `genus` as an object, which must be read through its own toJson().
  Map<String, dynamic> toJson() => {'name': name, 'genus': genus};
}

class Cart {
  final List<String> items;

  Cart(this.items);

  int get length => items.length;

  Map<String, dynamic> toJson() => {'items': items, 'total': items.length};
}

class Broken {
  final DateTime? createdAt = null;

  Map<String, dynamic> toJson() => {
    'createdAt': (createdAt as dynamic).toIso8601String(),
  };
}

class Parent {
  final Object child = Opaque();

  Map<String, dynamic> toJson() => {
    'name': 'parent',
    'child': (child as dynamic).toJson(),
  };
}

class Counted {
  var calls = 0;

  Map<String, dynamic> toJson() {
    calls++;
    return {'a': 1, 'b': 2};
  }
}

/// Generates ids with a prefix.
class PrefixedHeaderSyntax extends md.HeaderWithIdSyntax {
  const PrefixedHeaderSyntax();

  @override
  md.Node parse(md.BlockParser parser) {
    var element = super.parse(parser) as md.Element;
    element.generatedId = 'my-${element.generatedId}';
    return element;
  }
}

class Opaque {
  final String name = 'hidden';
}

void main() {
  late Angel app;

  Future<String> render(
    String template,
    Map<String, dynamic> locals, {
    bool escape = true,
    md.ExtensionSet? extensionSet,
  }) async {
    var fs = MemoryFileSystem();
    var views = fs.directory('views')..createSync();
    views.childFile('page.md').writeAsStringSync(template);
    app = Angel();
    await app.configure(
      markdown(views, escape: escape, extensionSet: extensionSet),
    );
    return await app.viewGenerator!('page', locals);
  }

  group('escaping', () {
    test('renders HTML in values as text', () async {
      var html = await render('Hi {{name}}', {
        'name': '<script>alert(1)</script>',
      });
      expect(html, isNot(contains('<script>')));
      expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    });

    test('renders Markdown in values as text', () async {
      var html = await render('{{link}}', {
        'link': '[click](javascript:alert(1)) *bold*',
      });
      expect(html, isNot(contains('<a')));
      expect(html, isNot(contains('<em>')));
      expect(html, contains('[click](javascript:alert(1)) *bold*'));
    });

    test('keeps entity-like text as it is', () async {
      expect(
        await render('{{v}}', {'v': '&lt; & \\'}),
        contains('&amp;lt; &amp; \\'),
      );
    });

    test('keeps values as they are in code spans and blocks', () async {
      var locals = {'cmd': 'npm run build:prod <x>'};
      expect(
        await render('`{{cmd}}`', locals),
        contains('<code>npm run build:prod &lt;x&gt;</code>'),
      );
      expect(
        await render('```\n{{cmd}}\n```', locals),
        contains('<pre><code>npm run build:prod &lt;x&gt;\n</code></pre>'),
      );
    });

    test('escapes values in HTML attributes', () async {
      var html = await render('<a href="{{url}}" title=\'{{t}}\'>x</a>', {
        'url': 'https://x.com/a?b=1&c=2',
        't': 'it\'s "q"',
      });
      expect(html, contains('href="https://x.com/a?b=1&amp;c=2"'));
      expect(html, contains('title=\'it&#39;s &quot;q&quot;\''));
    });

    test('puts values into the URLs of Markdown links', () async {
      var html = await render('[x]({{url}}) ![i]({{url}})', {
        'url': 'https://x.com/a',
      });
      expect(html, contains('<a href="https://x.com/a">x</a>'));
      expect(html, contains('<img src="https://x.com/a" alt="i" />'));
    });

    test('generates heading ids from the values', () async {
      expect(
        await render('# Hello {{name}}', {'name': 'Big World'}),
        contains('<h1 id="hello-big-world">Hello Big World</h1>'),
      );
      expect(
        await render('# *{{a}}* & {{b}}', {'a': 'Q', 'b': 'A'}),
        contains('<h1 id="q--a">'),
      );
    });

    test('generates heading ids as for the Markdown with the values', () async {
      Future<String> id(String heading, Map<String, dynamic> locals) async {
        var html = await render(heading, locals);
        return RegExp('id="([^"]*)"').firstMatch(html)![1]!;
      }

      // As for "# [Docs](/x)", every time.
      expect(await id('# [Docs]({{url}})', {'url': '/x'}), 'docsx');
      expect(await id('# [Docs]({{url}})', {'url': '/x'}), 'docsx');
      // Digits after a value are not taken for the index of its placeholder.
      expect(await id('# v{{n}}5', {'n': 1}), 'v15');
      expect(await id('# &copy; {{year}}', {'year': 2026}), 'copy-2026');
      expect(await id('#  {{v}}  ', {'v': ' Spaced Out '}), 'spaced-out');
      // As for "# ! a", which is trimmed before the "!" is removed.
      expect(await id('# !{{v}}', {'v': ' a'}), '-a');
      expect(await id('# {{x}}{{y}}', {'x': 'a ', 'y': ' '}), 'a');
      expect(await id('{{v}} Title\n===', {'v': 'Setext'}), 'setext-title');
    });

    test('keeps reference links and footnotes with values', () async {
      var html = await render(
        '[docs][{{ref}}] Note[^{{n}}]\n\n[{{ref}}]: /docs\n\n[^{{n}}]: note',
        {'ref': 'r', 'n': '1'},
      );
      expect(html, contains('<a href="/docs">docs</a>'));
      expect(html, contains('href="#fn-1"'));
      expect(html, contains('id="fn-1"'));
    });

    test('links footnotes with values to their ids', () async {
      var html = await render(
        '''
Note[^{{n}}]

[^{{n}}]: x''',
        {'n': 'my note&'},
      );
      expect(html, contains('href="#fn-my%20note%26"'));
      expect(html, contains('id="fn-my%20note%26"'));
      expect(html, contains('href="#fnref-my%20note%26"'));
      expect(html, contains('id="fnref-my%20note%26"'));
    });

    test('lists footnotes with values in the order of references', () async {
      var html = await render(
        '''
A[^{{x}}] B[^{{y}}]

[^{{y}}]: second

[^{{x}}]: first''',
        {'x': 'p', 'y': 'q'},
      );
      expect(html.indexOf('first'), lessThan(html.indexOf('second')));
    });

    test('replaces unsafe schemes made of values and text', () async {
      expect(
        await render('[go]({{proto}}:{{rest}})', {
          'proto': 'javascript',
          'rest': 'alert(1)',
        }),
        contains('<a href="#">go</a>'),
      );
      expect(
        await render('![i]({{url}})', {'url': 'javascript:alert(1)'}),
        contains('<img src="#" alt="i" />'),
      );
    });

    test('keeps schemes and hosts in the view itself', () async {
      for (var (view, href) in [
        ('[x](tel:{{v}})', 'tel:123'),
        ('[x](sms:{{v}})', 'sms:123'),
        ('[x](myapp://open/{{v}})', 'myapp://open/123'),
        ('[x](//cdn.example/{{v}})', '//cdn.example/123'),
        ('[x]({{empty}}//cdn.example/a)', '//cdn.example/a'),
        ('[x]({{empty}}tel:1)', 'tel:1'),
      ]) {
        expect(
          await render(view, {'v': '123', 'empty': ''}),
          contains('<a href="$href">x</a>'),
          reason: view,
        );
      }
    });

    test('keeps protocol-relative URLs of values', () async {
      expect(
        await render('[x]({{url}})', {'url': '//cdn.example/a'}),
        contains('<a href="//cdn.example/a">x</a>'),
      );
    });

    test('replaces unsafe schemes of values that start a link URL', () async {
      for (var url in [
        'javascript:alert(1)',
        'JavaScript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'vbscript:x',
      ]) {
        expect(
          await render('[x]({{url}})', {'url': url}),
          contains('<a href="#">x</a>'),
          reason: url,
        );
      }
      for (var url in [
        'https://x.com',
        'http://x.com',
        'mailto:a@x.com',
        '/p',
      ]) {
        expect(
          await render('[x]({{url}})', {'url': url}),
          contains('<a href="$url">x</a>'),
          reason: url,
        );
      }
      // Not a scheme once the space is encoded, so a relative URL.
      expect(
        await render('[x]({{url}})', {'url': ' javascript:x'}),
        contains('<a href="%20javascript:x">x</a>'),
      );
    });

    test('keeps subclasses of the heading syntaxes', () async {
      var extensionSet = md.ExtensionSet([
        const PrefixedHeaderSyntax(),
      ], const []);
      expect(
        await render('# Hello {{v}}', {
          'v': 'Big World',
        }, extensionSet: extensionSet),
        contains('<h1 id="my-hello-big-world">'),
      );
    });

    test('keeps the ids of headings without values', () async {
      var html = await render('# Hello *big* world\n\n# Q & A\n\n{{v}}', {
        'v': 'x',
      });
      expect(html, contains('<h1 id="hello-big-world">'));
      expect(html, contains('<h1 id="q--a">'));
    });

    test('leaves text that looks like a placeholder', () async {
      // Letters around an index, as placeholders are, but not their key.
      var html = await render('{{v}} abcdefgh5abcdefgh [l](/abc0abc)', {
        'v': 'x',
      });
      expect(html, contains('x abcdefgh5abcdefgh'));
      expect(html, contains('href="/abc0abc"'));
    });

    test('puts values next to letters and digits', () async {
      expect(
        await render('a{{v}}b{{v}}{{w}}9', {'v': 'X', 'w': 'Y'}),
        contains('<p>aXbXY9</p>'),
      );
    });

    test('percent-encodes values that start the URL of a link', () async {
      var html = await render('[x]({{url}})', {
        'url': 'https://x.com/a b?q=1&r=%20%zz#é',
      });
      expect(
        html,
        contains('href="https://x.com/a%20b?q=1&amp;r=%20%25zz#%C3%A9"'),
      );
    });

    test('percent-encodes values in URLs as components', () async {
      var html = await render('[x](/search?q={{q}}) [y](/p/{{q}})', {
        'q': 'a b&admin=1#f/../%20 é',
      });
      var encoded = 'a%20b%26admin%3D1%23f%2F..%2F%2520%20%C3%A9';
      expect(html, contains('href="/search?q=$encoded"'));
      expect(html, contains('href="/p/$encoded"'));
    });

    test('encodes unpaired surrogates in URLs', () async {
      var html = await render('[x](/p/{{v}})', {
        'v': 'a${String.fromCharCode(0xD800)}b',
      });
      expect(html, contains('href="/p/a%EF%BF%BDb"'));
    });

    test('keeps values with newlines inside a table cell', () async {
      var html = await render('| a | b |\n|---|---|\n| {{v}} | y |', {
        'v': 'one\n\n    two',
      });
      expect(html, contains('<td>one\n\n    two</td>'));
      expect(html, contains('<td>y</td>'));
    });

    test('does not escape the template itself', () async {
      expect(await render('*{{v}}*', {'v': 'x'}), contains('<em>x</em>'));
    });

    test('inserts values as Markdown with escape: false', () async {
      var html = await render('{{v}}', {'v': '*bold*'}, escape: false);
      expect(html, contains('<em>bold</em>'));
    });
  });

  group('view names', () {
    late Directory views;

    setUp(() async {
      var fs = MemoryFileSystem();
      fs.directory('/srv').createSync();
      fs.file('/srv/secret.md').writeAsStringSync('secret');
      views = fs.directory('/srv/views')..createSync();
      views.childFile('page.md').writeAsStringSync('page');
      fs.directory('/srv/views/docs').createSync();
      views.childFile('docs/intro.md').writeAsStringSync('intro');
      app = Angel();
      await app.configure(markdown(views));
    });

    test('render views in subdirectories', () async {
      expect(await app.viewGenerator!('docs/intro'), contains('intro'));
      expect(await app.viewGenerator!('docs/../page'), contains('page'));
    });

    test('render views through links inside the views directory', () async {
      views.fileSystem.link('/srv/views/alias').createSync('/srv/views/docs');
      expect(await app.viewGenerator!('alias/intro'), contains('intro'));
    });

    test('follows a views directory link that is pointed elsewhere', () async {
      var fs = views.fileSystem;
      fs.directory('/srv/v1').createSync();
      fs.file('/srv/v1/page.md').writeAsStringSync('one');
      fs.directory('/srv/v2').createSync();
      fs.file('/srv/v2/page.md').writeAsStringSync('two');
      var link = fs.link('/srv/current')..createSync('/srv/v1');
      app = Angel();
      await app.configure(markdown(fs.directory('/srv/current')));

      expect(await app.viewGenerator!('page'), contains('one'));
      link.updateSync('/srv/v2');
      expect(await app.viewGenerator!('page'), contains('two'));
    });

    test('rejects views through links outside the views directory', () {
      views.fileSystem.link('/srv/views/link').createSync('/srv');
      expect(
        app.viewGenerator!('link/secret'),
        throwsA(
          isA<AngelHttpException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    for (var name in [
      'missing',
      'docs/missing',
      // A directory, not a file.
      'folder',
    ]) {
      test('rejects "$name", which is not a view', () {
        views.fileSystem.directory('/srv/views/folder.md').createSync();
        expect(
          app.viewGenerator!(name),
          throwsA(
            isA<AngelHttpException>().having(
              (e) => e.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
      });
    }

    for (var name in ['../secret', 'docs/../../secret', '/srv/secret']) {
      test('rejects "$name", outside the views directory', () {
        expect(
          app.viewGenerator!(name),
          throwsA(
            isA<AngelHttpException>().having(
              (e) => e.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
      });
    }
  });

  test('reads keys of nested maps', () async {
    var html = await render('{{user.address.city}}', {
      'user': {
        'address': {'city': 'Kuching'},
      },
    });
    expect(html, contains('Kuching'));
  });

  test('reads members of objects with toJson()', () async {
    var html = await render('*{{species.genus.name}} {{species.name}}*', {
      'species': Species('sapiens', Genus('homo')),
    });
    expect(html, contains('<em>homo sapiens</em>'));
  });

  test('renders a root local without a member', () async {
    expect(await render('{{title}}', {'title': 'Hi'}), contains('Hi'));
  });

  test('reads common getters and list indexes', () async {
    var locals = {
      'items': ['a', 'b', 'c'],
      'empty': [],
      'name': 'Angel',
      'map': {'x': 1, 'length': 'own key'},
    };
    Future<String> value(String expr) async =>
        (await render('{{$expr}}', locals)).trim();

    expect(await value('items.length'), '<p>3</p>');
    expect(await value('items.first'), '<p>a</p>');
    expect(await value('items.last'), '<p>c</p>');
    expect(await value('items.1'), '<p>b</p>');
    expect(await value('items.isNotEmpty'), '<p>true</p>');
    expect(await value('empty.first'), '');
    expect(await value('name.length'), '<p>5</p>');
    // A key of a Map wins over its getter.
    expect(await value('map.length'), '<p>own key</p>');
    expect(
      render('{{items.3}}', locals),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('has 3 items, so it has no item 3'),
        ),
      ),
    );
  });

  test('reads only the JSON keys of objects with toJson()', () async {
    var locals = {
      'cart': Cart(['a', 'b', 'c']),
    };
    expect(await render('{{cart.total}}', locals), contains('<p>3</p>'));
    expect(
      render('{{cart.length}}', locals),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('"cart" has no member named "length"'),
        ),
      ),
    );
  });

  test('reports errors inside toJson() as they are', () async {
    expect(
      render('{{thing.createdAt}}', {'thing': Broken()}),
      throwsA(
        isA<NoSuchMethodError>().having(
          (e) => '$e',
          'message',
          contains('toIso8601String'),
        ),
      ),
    );
  });

  test('reports a missing toJson() inside toJson() as it is', () async {
    expect(
      render('{{thing.name}}', {'thing': Parent()}),
      throwsA(
        isA<NoSuchMethodError>().having(
          (e) => '$e',
          'message',
          contains("Class 'Opaque' has no instance method 'toJson'"),
        ),
      ),
    );
  });

  test('calls toJson() once per object and render', () async {
    var counted = Counted();
    expect(
      await render('{{c.a}} {{c.b}} {{c.a}}', {'c': counted}),
      contains('<p>1 2 1</p>'),
    );
    expect(counted.calls, 1);
  });

  test('ignores spaces around expressions and their parts', () async {
    var locals = {
      'title': 'Hi',
      'user': {'name': 'Bob'},
    };
    expect(await render('{{ title }}', locals), contains('<p>Hi</p>'));
    expect(await render('{{ user . name }}', locals), contains('<p>Bob</p>'));
  });

  test('renders null values as nothing', () async {
    var locals = {
      'subtitle': null,
      'user': {'name': null},
    };
    expect(await render('a{{subtitle}}b', locals), contains('<p>ab</p>'));
    expect(await render('a{{user.name}}b', locals), contains('<p>ab</p>'));
  });

  test('keeps @-prefixed braces raw', () async {
    expect(await render('@{{raw}}', {}), contains('{{raw}}'));
  });

  test('throws for a missing key', () async {
    expect(
      render('{{user.age}}', {
        'user': {'name': 'Bob'},
      }),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('"user" has no member named "age"'),
        ),
      ),
    );
  });

  test('throws for a member of null', () async {
    expect(
      render('{{user.name}}', {'user': null}),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('which is null'),
        ),
      ),
    );
  });

  test('throws for an object without toJson()', () async {
    expect(
      render('{{thing.name}}', {'thing': Opaque()}),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('toJson()'),
        ),
      ),
    );
  });
}
