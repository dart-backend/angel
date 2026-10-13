/// Framework features that read annotations through the reflector: `@Hooks`,
/// `@Middleware`, and `@Expose` controller routes.
library;

import 'dart:async';
import 'dart:convert';

import 'package:angel3_container_mirrors/angel3_container_mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

import 'common.dart';

@Expose('/items')
class ItemController extends Controller {
  String getItem(int id) => 'get $id';
  String putItem(int id) => 'put $id';
  String deleteItem(int id) => 'delete $id';
  // Verb-like prefixes that are not whole words: plain GET routes.
  String posts() => 'posts';
  String headers() => 'headers';
  String getter() => 'getter';
}

@Middleware([interceptor])
Future<String> testMiddlewareMetadata(
  RequestContext req,
  ResponseContext res,
) async {
  return 'This should not be shown.';
}

@Middleware([interceptService])
class QueryService extends Service {
  @override
  @Middleware([interceptor])
  Future<Map?> read(id, [Map? params]) async => params;
}

void interceptor(RequestContext req, ResponseContext res) {
  res
    ..write('Middleware')
    ..close();
}

bool interceptService(RequestContext req, ResponseContext res) {
  res.write('Service with ');
  return true;
}

void main() {
  late Angel app;
  late AngelHttp http;

  setUp(() {
    app = Angel(reflector: MirrorsReflector());
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

  test('@Hooks on a service and its methods', () async {
    final service = HookedService(IncrementService())..addHooks(app);
    expect(service.inner, isNot(const IsInstanceOf<MapService>()));
    IncrementService.times = 0;
    await service.index();
    expect(IncrementService.times, equals(2));
  });

  test('@Middleware on a route handler', () async {
    app.get('/meta', testMiddlewareMetadata);
    var (_, body) = await send('GET', '/meta');
    expect(body, equals('Middleware'));
  });

  test('@Middleware on a service and its methods', () async {
    app.use('/query', QueryService());
    var (_, body) = await send('GET', '/query/foo?bar=baz');
    expect(body, equals('Service with Middleware'));
  });

  group('controller verb inference', () {
    setUp(() async {
      await app.configure(ItemController().configureServer);
    });

    for (var (method, path, expected) in [
      ('GET', '/items/item/5', 'get 5'),
      ('PUT', '/items/item/5', 'put 5'),
      ('DELETE', '/items/item/5', 'delete 5'),
      ('GET', '/items/posts', 'posts'),
      ('GET', '/items/headers', 'headers'),
      ('GET', '/items/getter', 'getter'),
    ]) {
      test('$method $path', () async {
        var (status, body) = await send(method, path);
        expect(status, 200);
        expect(json.decode(body), expected);
      });
    }

    test('putItem is no longer GET /put_item', () async {
      var (status, _) = await send('GET', '/items/put_item/5');
      expect(status, 404);
    });
  });
}
