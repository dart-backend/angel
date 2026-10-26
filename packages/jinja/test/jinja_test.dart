import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_jinja/angel3_jinja.dart';
import 'package:jinja/jinja.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String views;

  void write(String path, String contents) => File(p.join(temp.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);

  Future<Angel> configure({
    String environment = 'development',
    Object? defaultValue,
    bool followLinks = true,
  }) async {
    var app = Angel(environment: AngelEnvironment(environment));
    await app.configure(
      jinja(path: views, defaultValue: defaultValue, followLinks: followLinks),
    );
    return app;
  }

  Matcher isNotFound() => throwsA(
    isA<AngelHttpException>().having((e) => e.statusCode, 'statusCode', 404),
  );

  setUp(() {
    temp = Directory.systemTemp.createTempSync('angel3_jinja');
    views = p.join(temp.path, 'views');
    write('secret.html', 'SECRET');
    write('views/layout.html', '<b>{% block body %}{% endblock %}</b>');
    write(
      'views/hello.html',
      '{% extends "layout.html" %}{% block body %}'
          'hello {{ name | e }}{% include "partials/sign.html" %}'
          '{% endblock %}',
    );
    write('views/partials/sign.html', '!');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('renders a view, with its layout and includes', () async {
    var app = await configure();
    expect(
      await app.viewGenerator!('hello.html', {'name': '<i>'}),
      '<b>hello &lt;i&gt;!</b>',
    );
  });

  test('a view that does not exist is a 404', () async {
    var app = await configure();
    await expectLater(app.viewGenerator!('missing.html'), isNotFound());
  });

  test('a view outside the views directory is a 404', () async {
    var app = await configure();
    for (var name in ['../secret.html', p.join(temp.path, 'secret.html')]) {
      await expectLater(app.viewGenerator!(name), isNotFound());
    }
  });

  test('a view without one of the extensions is a 404', () async {
    write('views/notes.txt', 'NOTES');
    var app = await configure();
    await expectLater(app.viewGenerator!('notes.txt'), isNotFound());
  });

  test('a symbolic link out of the views directory is a 404', () async {
    Link(p.join(views, 'link.html'))
        .createSync(p.join(temp.path, 'secret.html'));
    var app = await configure();
    await expectLater(app.viewGenerator!('link.html'), isNotFound());
  });

  test('without followLinks, a link within the views is a 404', () async {
    Link(p.join(views, 'link.html')).createSync(p.join(views, 'layout.html'));
    expect(await (await configure()).viewGenerator!('link.html'), '<b></b>');
    var app = await configure(followLinks: false);
    await expectLater(app.viewGenerator!('link.html'), isNotFound());
  });

  test('an include outside the views directory is not found', () async {
    write('views/page.html', '{% include "../secret.html" %}');
    var app = await configure();
    await expectLater(
      app.viewGenerator!('page.html'),
      throwsA(isA<TemplateNotFound>()),
    );
  });

  test('a template named by a variable is found', () async {
    write('views/page.html', '{% include name %}');
    var app = await configure();
    expect(
      await app.viewGenerator!('page.html', {'name': 'partials/sign.html'}),
      '!',
    );
  });

  test('an undefined variable renders as defaultValue', () async {
    write('views/page.html', '[{{ missing }}]');
    var app = await configure(defaultValue: 'none');
    expect(await app.viewGenerator!('page.html'), '[none]');
  });

  test('in production, templates are kept', () async {
    var app = await configure(environment: 'production');
    expect(
      await app.viewGenerator!('hello.html', {'name': 'a'}),
      '<b>hello a!</b>',
    );
    write('views/partials/sign.html', '?');
    expect(
      await app.viewGenerator!('hello.html', {'name': 'a'}),
      '<b>hello a!</b>',
    );
  });

  test('outside production, changes are seen', () async {
    var app = await configure();
    expect(
      await app.viewGenerator!('hello.html', {'name': 'a'}),
      '<b>hello a!</b>',
    );
    write('views/partials/sign.html', '?');
    expect(
      await app.viewGenerator!('hello.html', {'name': 'a'}),
      '<b>hello a?</b>',
    );
  });

  test('a custom loader is used, and a missing view is a 404', () async {
    var app = Angel();
    await app.configure(
      jinja(createLoader: () => MapLoader({'a.html': 'A{{ x }}'})),
    );
    expect(await app.viewGenerator!('a.html', {'x': 1}), 'A1');
    await expectLater(app.viewGenerator!('b.html'), isNotFound());
  });
}
