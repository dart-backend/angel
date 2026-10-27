import 'package:angel3_route/angel3_route.dart';
import 'package:test/test.dart';

void main() {
  List<String> handlersFor(Router<String> router, String path) =>
      router.resolveAbsolute(path).first.allHandlers;

  test('group middleware runs before the route', () {
    var router = Router<String>()
      ..group('/a', (r) => r.get('/b', 'h'), middleware: ['mw']);
    expect(handlersFor(router, '/a/b'), ['mw', 'h']);
  });

  test('nested group middleware runs outermost first', () {
    var router = Router<String>()
      ..group('/a', (r) {
        r.group('/b', (r) => r.get('/c', 'h'), middleware: ['inner']);
      }, middleware: ['outer']);
    expect(handlersFor(router, '/a/b/c'), ['outer', 'inner', 'h']);
  });

  test('group middleware applies to a group at the root path', () {
    var router = Router<String>()
      ..group('/', (r) => r.get('/x', 'h'), middleware: ['mw']);
    expect(handlersFor(router, '/x'), ['mw', 'h']);
  });

  test('a mounted router keeps its middleware', () {
    var router = Router<String>()
      ..mount(
        '/m',
        Router<String>()
          ..group('/', (r) => r.get('/x', 'h'), middleware: ['mw']),
      );
    expect(handlersFor(router, '/m/x'), ['mw', 'h']);
  });

  test('flatten keeps group middleware', () {
    var router = Router<String>()
      ..group('/a', (r) {
        r.group('/b', (r) => r.get('/c', 'h'), middleware: ['inner']);
      }, middleware: ['outer']);
    expect(handlersFor(flatten(router), '/a/b/c'), ['outer', 'inner', 'h']);
  });

  test('chain with group does not run middleware twice', () {
    var router = Router<String>()
      ..chain(['a']).group('/b', (r) => r.get('/c', 'h'), middleware: ['m']);
    expect(handlersFor(router, '/b/c'), ['a', 'm', 'h']);
  });

  test('a router mounted on a chain gets the chained middleware', () {
    var router = Router<String>();
    router.chain(['a']).mount('/m', Router<String>()..get('/x', 'h'));
    expect(handlersFor(router, '/m/x'), ['a', 'h']);
  });

  group('chained middleware on a mounted router', () {
    test('does not apply where the router is mounted without the chain', () {
      var api = Router<String>()..get('/x', 'h');
      var router = Router<String>();
      router.chain(['auth']).mount('/private', api);
      router.mount('/public', api);
      expect(handlersFor(router, '/private/x'), ['auth', 'h']);
      expect(handlersFor(router, '/public/x'), ['h']);
    });

    test('does not leak into another router', () {
      var api = Router<String>()..get('/x', 'h');
      Router<String>().chain(['auth']).mount('/private', api);
      var other = Router<String>();
      other.chain(['c']).mount('/a', api);
      expect(handlersFor(other, '/a/x'), ['c', 'h']);
    });

    test('runs once per mount when mounted twice on one chain', () {
      var api = Router<String>()..get('/x', 'h');
      var router = Router<String>();
      var chained = router.chain(['auth']);
      chained.mount('/one', api);
      chained.mount('/two', api);
      expect(handlersFor(router, '/one/x'), ['auth', 'h']);
      expect(handlersFor(router, '/two/x'), ['auth', 'h']);
    });
  });
}
