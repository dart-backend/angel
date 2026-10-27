import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_jael/angel3_jael.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:file/memory.dart';
import 'package:jael3/jael3.dart';
import 'package:test/test.dart';

import 'models.dart';

/// The members of a model in a template, read through the app's reflector,
/// without `dart:mirrors`.
void main() {
  Future<String> render(
    Reflector reflector, {
    MemberResolver? memberResolver,
  }) async {
    var app = Angel(reflector: reflector);
    var views = MemoryFileSystem().directory('views')..createSync();
    views
        .childFile('repo.jael')
        .writeAsStringSync(
          '<p>{{ repo.id }} {{ repo.name }} {{ repo.stars }} '
          '{{ repo.popular }} {{ repo.name.length }}</p>',
        );
    app.get(
      '/',
      (req, res) => res.render('repo', {'repo': Repo('angel', 120, id: '7')}),
    );
    await app.configure(
      jael(views, minified: true, memberResolver: memberResolver),
    );
    var client = await connectTo(app);
    try {
      return (await client.get(Uri.parse('/'))).body;
    } finally {
      await client.close();
    }
  }

  test('of a StaticReflector of the generated data', () async {
    expect(
      await render(StaticReflector.combine([modelsReflection])),
      '<p>7 angel 120 true 5</p>',
    );
  });

  test('after those of the memberResolver given', () async {
    expect(
      await render(
        StaticReflector.combine([modelsReflection]),
        memberResolver: (target, name) =>
            target is Repo && name == 'name' ? 'ANGEL' : noMember,
      ),
      '<p>7 ANGEL 120 true 5</p>',
    );
  });

  test('none of the default ThrowingReflector', () async {
    // Each is null, as of `strictResolution: false`, the default of `jael`.
    var body = await render(const ThrowingReflector());
    expect(body.replaceAll(' ', ''), '<p></p>');
  });
}
