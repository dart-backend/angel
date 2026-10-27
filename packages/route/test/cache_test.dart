import 'package:angel3_route/angel3_route.dart';
import 'package:test/test.dart';

void main() {
  group('the resolve cache', () {
    test('holds at most maxSize results', () {
      var router = Router<String>()
        ..get('/u/:id', 'h')
        ..enableCache(maxSize: 10);
      for (var i = 0; i < 100; i++) {
        router.resolveAbsolute('/u/$i');
      }
      expect(router.cacheLength, 10);
    });

    test('still resolves paths after they are evicted', () {
      var router = Router<String>()
        ..get('/u/:id', 'h')
        ..enableCache(maxSize: 2);
      for (var i = 0; i < 5; i++) {
        expect(router.resolveAbsolute('/u/$i').first.allParams, {'id': '$i'});
      }
      expect(router.resolveAbsolute('/u/0').first.allParams, {'id': '0'});
    });

    test('keeps recently used results', () {
      var router = Router<String>()
        ..get('/u/:id', 'h')
        ..enableCache(maxSize: 2);
      var first = router.resolveAbsolute('/u/0');
      router.resolveAbsolute('/u/1');
      router.resolveAbsolute('/u/0'); // now the most recently used
      router.resolveAbsolute('/u/2'); // evicts /u/1
      expect(router.resolveAbsolute('/u/0'), same(first));
    });

    test('tells apart different relative paths', () {
      var router = Router<String>()
        ..get('/a', 'a')
        ..get('/b', 'b')
        ..enableCache();
      expect(router.resolveAll('/x', '/a').first.handlers, ['a']);
      expect(router.resolveAll('/x', '/b').first.handlers, ['b']);
    });

    test('flatten enables a bounded cache', () {
      var router = flatten(Router<String>()..get('/u/:id', 'h'));
      for (var i = 0; i < 2000; i++) {
        router.resolveAbsolute('/u/$i');
      }
      expect(router.cacheLength, lessThanOrEqualTo(1024));
    });
  });

  group('malformed percent-encoding', () {
    var router = Router<String>()
      ..get('/u/:id', 'param')
      ..get('/n/int:id', 'typed')
      ..get('/o/:id?', 'optional')
      ..get('/*', 'fallback');

    for (var path in ['/u/%zz', '/n/%zz', '/o/%zz']) {
      test('$path does not match the parameter route', () {
        var handlers = router.resolveAbsolute(path).map((r) => r.handlers);
        expect(handlers, [
          ['fallback'],
        ]);
      });
    }

    test('a typed parameter with text that is not a number does not match', () {
      expect(router.resolveAbsolute('/n/abc').map((r) => r.handlers), [
        ['fallback'],
      ]);
      expect(router.resolveAbsolute('/n/5').first.allParams, {'id': 5});
    });

    test('valid percent-encoding is still decoded', () {
      expect(router.resolveAbsolute('/u/%41').first.allParams, {'id': 'A'});
    });
  });
}
