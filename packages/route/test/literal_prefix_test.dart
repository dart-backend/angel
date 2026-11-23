import 'package:angel3_route/angel3_route.dart';
import 'package:test/test.dart';

/// The handlers of the routes of [router] that [path] matches.
List<String> matches(
  Router<String> router,
  String path, [
  String method = 'GET',
]) => [
  for (var r in router.resolveAbsolute(path, method: method)) ...r.handlers,
];

void main() {
  // Routes whose path starts with constant text, then something else, so
  // that a path is checked against that text before the route is parsed.
  var router = Router<String>()
    ..get('/', 'root')
    ..get('/:id', 'param-first')
    ..get('/users/:id', 'users-id')
    ..get('/users/:id/posts/:post', 'users-posts')
    ..get('/user', 'user')
    ..get('/files/*', 'files-wildcard')
    ..get('/opt/:a?', 'optional')
    ..get('/num/int:n', 'typed')
    ..get('/re/:id([0-9]+)', 'regex')
    ..get('/v:version/api', 'pre-param')
    ..get('/a/b/c', 'constants')
    ..post('/users/:id', 'post-users');
  router.group('/api/v1', (r) {
    r.get('/', 'api-root');
    r.get('/items/:id', 'api-items');
    r.group('/deep', (d) => d.get('/x', 'api-deep'));
  });

  test('a route of constants then a parameter', () {
    expect(matches(router, '/users/7'), contains('users-id'));
    expect(matches(router, '/users/7/posts/9'), contains('users-posts'));
    expect(matches(router, '/users/7', 'POST'), ['post-users']);
  });

  test('a constant that only starts a segment of the path', () {
    expect(matches(router, '/user'), contains('user'));
    expect(matches(router, '/users'), isNot(contains('user')));
  });

  test('routes that start with a parameter, or with nothing', () {
    expect(matches(router, '/'), ['root']);
    expect(matches(router, '/anything'), contains('param-first'));
  });

  test('wildcard, optional, typed, regex and prefixed parameters', () {
    expect(matches(router, '/files/a/b.txt'), contains('files-wildcard'));
    expect(matches(router, '/opt'), contains('optional'));
    expect(matches(router, '/opt/1'), contains('optional'));
    expect(matches(router, '/num/12'), contains('typed'));
    expect(matches(router, '/re/12'), contains('regex'));
    expect(matches(router, '/re/ab'), isNot(contains('regex')));
    expect(matches(router, '/v2/api'), contains('pre-param'));
  });

  test('a route of constants only', () {
    expect(matches(router, '/a/b/c'), ['constants']);
    expect(matches(router, '/a/b'), isEmpty);
    expect(matches(router, '/a/bc'), isEmpty);
  });

  test('the routes of groups', () {
    expect(matches(router, '/api/v1'), ['api-root']);
    expect(matches(router, '/api/v1/items/3'), ['api-items']);
    expect(matches(router, '/api/v1/deep/x'), ['api-deep']);
    expect(matches(router, '/api/v2/items/3'), isEmpty);
  });

  test('of a flattened router, as in production', () {
    var flat = flatten(router);
    expect(matches(flat, '/api/v1/items/3'), ['api-items']);
    expect(matches(flat, '/users/7/posts/9'), contains('users-posts'));
    expect(matches(flat, '/a/b/c'), ['constants']);
  });
}
