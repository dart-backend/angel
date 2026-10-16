import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_markdown/angel3_markdown.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
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

class Opaque {
  final String name = 'hidden';
}

void main() {
  late Angel app;

  Future<String> render(
    String template,
    Map<String, dynamic> locals, {
    bool escape = true,
  }) async {
    var fs = MemoryFileSystem();
    var views = fs.directory('views')..createSync();
    views.childFile('page.md').writeAsStringSync(template);
    app = Angel();
    await app.configure(markdown(views, escape: escape));
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
