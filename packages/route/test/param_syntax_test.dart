import 'package:angel3_route/angel3_route.dart';
import 'package:test/test.dart';

void main() {
  /// The params of the first match of [path], or `null` for no match.
  Map<String, dynamic>? paramsFor(String route, String path) {
    var router = Router<String>()..get(route, 'h');
    var results = router.resolveAbsolute(path);
    return results.isEmpty ? null : results.first.allParams;
  }

  group('a parameter restricted by a RegExp', () {
    test('as the first segment', () {
      expect(paramsFor('/:id([0-9]+)', '/42'), {'id': '42'});
      expect(paramsFor('/:id([0-9]+)', '/abc'), isNull);
    });

    test('after another segment', () {
      expect(paramsFor('/n/:id([0-9]+)', '/n/42'), {'id': '42'});
      expect(paramsFor('/n/:id([0-9]+)', '/n/abc'), isNull);
    });

    test('with groups of its own', () {
      expect(paramsFor('/c/:color(red|(gr(ee)n))', '/c/green'), {
        'color': 'green',
      });
    });
  });

  group('a parameter with text around it', () {
    test('before', () {
      expect(paramsFor('/f/file-:id', '/f/file-7'), {'id': '7'});
    });

    test('after', () {
      expect(paramsFor('/f/:id.json', '/f/7.json'), {'id': '7'});
      expect(paramsFor('/f/:id.json', '/f/7.xml'), isNull);
    });

    test('is matched literally', () {
      expect(paramsFor('/v/v1.:id', '/v/v1.5'), {'id': '5'});
      expect(paramsFor('/v/v1.:id', '/v/v1x5'), isNull);
    });
  });

  test('a typed parameter', () {
    expect(paramsFor('/t/int:id([0-9]+)', '/t/5'), {'id': 5});
    expect(paramsFor('/t/double:n', '/t/2.5'), {'n': 2.5});
  });

  group('an optional parameter', () {
    test('after another segment', () {
      expect(paramsFor('/x/:id?', '/x/5'), {'id': '5'});
      expect(paramsFor('/x/:id?', '/x'), <String, dynamic>{});
      expect(paramsFor('/x/:id?', '/x/NULL'), {'id': 'NULL'});
    });

    test('as the first segment', () {
      expect(paramsFor('/:id?', '/5'), {'id': '5'});
      expect(paramsFor('/:id?', '/'), <String, dynamic>{});
    });

    test('restricted by a RegExp', () {
      expect(paramsFor('/x/:id?([0-9]+)', '/x/5'), {'id': '5'});
      expect(paramsFor('/x/:id?([0-9]+)', '/x'), <String, dynamic>{});
      expect(paramsFor('/x/:id?([0-9]+)', '/x/a'), isNull);
    });
  });
}
