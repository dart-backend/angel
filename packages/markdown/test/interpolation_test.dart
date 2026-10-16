import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_markdown/angel3_markdown.dart';
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

  Future<String> render(String template, Map<String, dynamic> locals) async {
    var fs = MemoryFileSystem();
    var views = fs.directory('views')..createSync();
    views.childFile('page.md').writeAsStringSync(template);
    app = Angel();
    await app.configure(markdown(views));
    return await app.viewGenerator!('page', locals);
  }

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
