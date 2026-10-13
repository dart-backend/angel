import 'dart:convert';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

import 'fixtures/app.dart';

/// The framework's annotation-driven features, with the reflection data
/// generated for `fixtures/app.dart` instead of `dart:mirrors`; the same
/// cases as `framework_mirrors_test`'s `metadata_test.dart`.
void main() {
  late Angel app;
  late AngelHttp http;

  setUp(() {
    app = Angel(reflector: StaticReflector.combine([appReflection]));
    http = AngelHttp(app);
  });

  Future<(int, String)> send(String method, String path) async {
    var rq = MockHttpRequest(method, Uri.parse(path))
      ..headers.set('accept', 'application/json');
    await rq.close();
    await http.handleRequest(rq);
    var body = await rq.response.transform(utf8.decoder).join();
    return (rq.response.statusCode, body);
  }

  group('an @Expose controller', () {
    setUp(() => app.configure(ItemController().configureServer));

    for (var (method, path, expected) in [
      ('GET', '/items/item/5', 'get 5'),
      ('PUT', '/items/item/5', 'put 5'),
      ('DELETE', '/items/item/5', 'delete 5'),
      ('GET', '/items/posts', 'posts'),
      ('GET', '/items/headers', 'headers'),
      ('GET', '/items/getter', 'getter'),
    ]) {
      test('routes $method $path', () async {
        expect(await send(method, path), (200, json.encode(expected)));
      });
    }

    test('injects a @Query parameter', () async {
      expect(await send('GET', '/items/search?q=dart'), (
        200,
        json.encode('search dart'),
      ));
    });

    test('skips a @noExpose method', () async {
      expect((await send('GET', '/items/hidden')).$1, 404);
    });

    test('is named after its class', () {
      expect(app.controllers.keys, contains('ItemController'));
    });
  });

  test('an @Expose that names a static member of its class', () async {
    await app.configure(LimitsController().configureServer);
    expect(await send('GET', '/limits/max'), (200, json.encode('max')));
  });

  test('@Middleware on a service and its methods', () async {
    app.use('/query', QueryService());
    expect((await send('GET', '/query/foo')).$2, 'Service with Middleware');
  });

  test('@Hooks on a service and its methods', () async {
    var service = HookedService(CountedService())..addHooks(app);
    hookCalls = 0;
    await service.index();
    expect(hookCalls, 2);
  });

  test('@Middleware on a top-level handler', () async {
    app.get('/meta', annotatedHandler);
    expect((await send('GET', '/meta')).$2, 'Middleware');
  });

  test('ioc on a top-level function', () async {
    app.get('/hello/:name', ioc(hello));
    expect(await send('GET', '/hello/bob'), (200, json.encode('Hello, bob!')));
  });
}
