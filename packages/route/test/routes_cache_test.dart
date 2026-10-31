import 'package:angel3_route/angel3_route.dart';
import 'package:test/test.dart';

/// The routes of a group are expanded once, so their parsers are compiled
/// once, not on every resolution:
/// https://github.com/dart-backend/angel/issues/114
void main() {
  late Router<String> router;
  late Router<String> group;

  setUp(() {
    router = Router<String>()..get('/', 'root');
    router.chain(['mw']).group('/api', (r) {
      group = r;
      r.get('/a', 'a');
    });
  });

  test('keeps the same routes between calls', () {
    expect(router.routes.last, same(router.routes.last));
    expect(
      () => router.routes.add(Route('/x', method: 'GET', handlers: [])),
      throwsUnsupportedError,
    );
  });

  test('includes a route added to a group after it was used', () {
    var before = router.routes;
    expect(router.resolveAbsolute('/api/b'), isEmpty);

    group.get('/b', 'b');
    expect(router.routes, isNot(same(before)));
    expect(router.resolveAbsolute('/api/b').first.route.handlers, ['mw', 'b']);
  });

  test('includes a route added to the router after it was used', () {
    router.routes;
    router.get('/c', 'c');
    expect(router.resolveAbsolute('/c').first.route.handlers, ['c']);
  });

  test('includes a router mounted after it was used', () {
    router.routes;
    router.mount('/m', Router<String>()..get('/d', 'd'));
    expect(router.resolveAbsolute('/m/d').first.route.handlers, ['d']);
  });
}
