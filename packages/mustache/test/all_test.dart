import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_mustache/angel3_mustache.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() async {
  var angel = Angel();
  await angel.configure(mustache(const LocalFileSystem().directory('./test')));

  test('can render templates', () async {
    var hello = await angel.viewGenerator!('hello', {'name': 'world'});
    var bar = await angel.viewGenerator!('foo/bar', {'framework': 'angel'});

    expect(hello, equals('Hello, world!'));
    expect(bar, equals('angel_framework'));
  });

  test('a view that is not found is a 404', () {
    expect(
      Future(() async {
        var fails = await angel.viewGenerator!('fail', {'this_should': 'fail'});
        print(fails);
      }),
      throwsA(
        isA<AngelHttpException>().having(
          (e) => e.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
  });

  test('partials', () async {
    var withPartial = await angel.viewGenerator!('with-partial');
    expect(withPartial, equals('Hello, world!'));
  });

  test('a view outside the views directory is a 404', () async {
    var app = Angel();
    await app.configure(
      mustache(const LocalFileSystem().directory('./test/foo')),
    );
    for (var name in ['../hello', '/etc/hostname']) {
      await expectLater(
        app.viewGenerator!(name),
        throwsA(isA<AngelHttpException>()),
      );
    }
  });

  group('in memory', () {
    late FileSystem fs;
    late Angel app;

    void write(String path, String contents) => fs.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);

    Future<void> configure({String environment = 'development'}) async {
      app = Angel(environment: AngelEnvironment(environment));
      await app.configure(mustache(fs.directory('/views')));
    }

    setUp(() async {
      fs = MemoryFileSystem();
      write('/secret.mustache', 'SECRET');
      await configure();
    });

    test('a partial that does not exist renders as nothing', () async {
      write('/views/page.mustache', '[{{> missing}}]');
      expect(await app.viewGenerator!('page'), '[]');
    });

    test('a symbolic link out of the views directory is a 404', () async {
      fs
          .link('/views/link.mustache')
          .createSync('/secret.mustache', recursive: true);
      await expectLater(
        app.viewGenerator!('link'),
        throwsA(isA<AngelHttpException>()),
      );
    });

    test(
      'partials of partials, and with other delimiters, are found',
      () async {
        write('/views/partials/a.mustache', 'A{{> b}}');
        write('/views/partials/b.mustache', 'B');
        write('/views/partials/c.mustache', 'C');
        write('/views/page.mustache', '{{> a}}{{=<% %>=}}<%> c%>');
        expect(await app.viewGenerator!('page'), 'ABC');
      },
    );

    test('in production, views and partials are kept', () async {
      await configure(environment: 'production');
      write('/views/page.mustache', '{{> p}}');
      write('/views/partials/p.mustache', 'one');
      expect(await app.viewGenerator!('page'), 'one');
      write('/views/page.mustache', 'changed');
      write('/views/partials/p.mustache', 'two');
      expect(await app.viewGenerator!('page'), 'one');
    });

    test('outside production, changes are seen', () async {
      write('/views/page.mustache', '{{> p}}');
      write('/views/partials/p.mustache', 'one');
      expect(await app.viewGenerator!('page'), 'one');
      write('/views/partials/p.mustache', 'two');
      expect(await app.viewGenerator!('page'), 'two');
    });
  });
}
