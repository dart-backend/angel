import 'package:angel3_route/angel3_route.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:test/test.dart';

/// A router matches a route with a single RegExp where it can, which must
/// give exactly what the route's parser gives: whether it matches, its
/// parameters, its tail and its span.
void main() {
  const patterns = [
    '',
    '/',
    'a',
    'a/b/c',
    ':id',
    'user/:id',
    'users/:id/posts/:post',
    ':a/:a',
    'o/:id?',
    ':a?',
    'opt/:a?/b',
    'opt/:a?/:b?',
    'int/int:id',
    'num/num:id',
    'double/double:id',
    'n/int:id?',
    'v:version/api',
    'x:id-y',
    ':id([0-9]+)',
    'a/:id([0-9]+)/b',
    ':id(\\d+)x',
    ':id((a)(b))',
    // The parser commits to `a`, then fails at `/`; a RegExp that
    // backtracked into `ab` would match `ab/b`.
    ':x(a|ab)/b',
    ':x(a|ab)',
    'int:n([0-9]+)',
    '*',
    'files/*',
    'songs/*/key',
    'pre*post',
    'isnt/she/*',
    'a/*/b/*',
    'w/a.b*',
    // Left to the parser: a backreference, a named group, a group by `*`.
    'back/:x((a)\\1)',
    'named/:n((?<g>\\d+))',
    'w/(x)*',
  ];

  const paths = [
    '',
    '/',
    'a',
    'a/',
    '/a/',
    'a/b/c',
    'a/b/c/d',
    'a//b',
    'user/42',
    'user/4%202',
    'user/%FF',
    'user/%zz',
    'user/42/x',
    'users/1/posts/2',
    '1/2',
    'o',
    'o/5',
    'opt/b',
    'opt/x/b',
    'opt',
    'opt/1',
    'opt/1/2',
    'int/12',
    'int/1x',
    'int/-3',
    'num/1.5',
    'double/2.5e3',
    'double/x',
    'n',
    'n/7',
    'v2/api',
    'vx/api',
    'v/api',
    'x5-y',
    'x-y',
    '123',
    'a/12/b',
    'a/x/b',
    '12x',
    'ab',
    'ab/b',
    'a/b',
    'files',
    'files/',
    'files/a/b/c',
    'songs/x/key',
    'songs/x/y/key',
    'preABCpost',
    'prepost',
    'isnt/she/lovely',
    'a/q/b/r/s',
    'back/aa',
    'named/12',
    'w/aXbcd',
    'w/xyz',
  ];

  /// What the route's parser gives for [path], as a router would use it.
  String viaParser(String pattern, String path) {
    var route = Route(pattern, method: 'GET', handlers: [0]);
    var scanner = SpanScanner(strip(path));
    try {
      var result = route.parser?.parse(scanner);
      if (result == null || !result.successful || !scanner.isDone) {
        return 'no match';
      }
      var value = result.value!;
      return describe(value.params, (value.tail ?? '') + scanner.rest);
    } catch (_) {
      // A parameter that cannot be read: the route does not match.
      return 'no match';
    }
  }

  String viaRouter(String pattern, String path) {
    var router = Router<int>()..get(pattern, 0);
    // As the framework does: stripStraySlashes cannot strip '' or '/'.
    var results = router.resolveAbsolute(strip(path), strip: false);
    if (results.isEmpty) return 'no match';
    var result = results.first;
    return describe(result.parseResult.value!.params, result.tail);
  }

  for (var pattern in patterns) {
    test('"$pattern" matches as its parser does', () {
      for (var path in paths) {
        expect(
          viaRouter(pattern, path),
          viaParser(pattern, path),
          reason: '"$pattern" on "$path"',
        );
      }
    });
  }

  test('a match has the span of the path it matched', () {
    var router = Router<int>()..get('users/:id/posts/:post', 0);
    var result = router.resolveAbsolute('/users/1/posts/2').first;
    expect(result.parseResult.span?.text, 'users/1/posts/2');
    expect(result.parseResult.successful, isTrue);
  });

  test('a mounted router matches its routes after the mount path', () {
    var api = Router<int>()..get('users/:id', 1);
    var router = Router<int>()..mount('api/v:version', api);
    var result = router.resolveAbsolute('/api/v2/users/7').first;
    expect(result.allParams, {'version': '2', 'id': '7'});
    expect(router.resolveAbsolute('/api/v2/users'), isEmpty);
  });
}

String strip(String path) => path.replaceAll(RegExp(r'^/+|/+$'), '');

String describe(Map<String, dynamic> params, String tail) {
  var entries = [
    for (var e in params.entries)
      '${e.key}=${e.value} (${e.value.runtimeType})',
  ];
  return 'params: {${entries.join(', ')}}, tail: "$tail"';
}
