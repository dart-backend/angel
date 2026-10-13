import 'dart:convert';

import 'package:angel3_container_mirrors/angel3_container_mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  late Angel app;
  late AngelHttp http;

  setUp(() {
    app = Angel(reflector: MirrorsReflector());
    http = AngelHttp(app);
  });

  Future<(int, String)> get(String path, {Map<String, String>? headers}) async {
    var rq = MockHttpRequest('GET', Uri.parse(path))
      ..headers.set('accept', 'application/json');
    headers?.forEach(rq.headers.set);
    await rq.close();
    await http.handleRequest(rq);
    var body = await rq.response.transform(utf8.decoder).join();
    return (rq.response.statusCode, body);
  }

  group('ioc', () {
    test('keeps the default of an unresolved named parameter', () async {
      app.get('/', ioc(({int limit = 10}) => limit));
      expect(await get('/'), (200, '10'));
    });

    test(
      'keeps the default of an unresolved nullable named parameter',
      () async {
        app.get('/', ioc(({String? q = 'default'}) => q));
        expect(await get('/'), (200, '"default"'));
      },
    );

    test('still resolves a named parameter', () async {
      app.get('/:q', ioc(({String? q = 'default'}) => q));
      expect(await get('/x'), (200, '"x"'));
    });

    test('passes null to an unresolved required named parameter', () async {
      app.get('/', ioc(({required String? q}) => q ?? 'none'));
      expect(await get('/'), (200, '"none"'));
    });

    test('reads a @Header parameter of a non-primitive type', () async {
      app.get('/', ioc((@Header('x-foo') Object foo) => foo));
      expect(await get('/', headers: {'x-foo': 'bar'}), (200, '"bar"'));
    });

    test('passes null for an optional parameter that cannot be made', () async {
      app.get('/', ioc((RequestContext req, [_Abstract? a]) => '$a'));
      expect(await get('/'), (200, '"null"'));
    });

    test('fails when making an optional parameter throws', () async {
      app.get('/', ioc((RequestContext req, [_Failing? f]) => '$f'));
      var (status, _) = await get('/');
      expect(status, 500);
    });

    test('still makes an optional parameter that can be made', () async {
      app.container.registerSingleton<_Abstract>(_Impl());
      app.get('/', ioc((RequestContext req, [_Abstract? a]) => '$a'));
      expect(await get('/'), (200, '"impl"'));
    });
  });

  group('controllers', () {
    test('ignore getters, setters, static and private methods', () async {
      await app.mountController<_MixedController>();
      expect(await get('/mixed/hello'), (200, '"hi"'));
      for (var path in ['/mixed/greeting', '/mixed/helper', '/mixed/_hidden']) {
        expect((await get(path)).$1, 404, reason: path);
      }
    });
  });
}

abstract class _Abstract {}

class _Impl implements _Abstract {
  @override
  String toString() => 'impl';
}

@Expose('/mixed')
class _MixedController extends Controller {
  String _value = 'hi';

  @Expose('/hello')
  String hello() => _hidden();

  String get greeting => 'Hello, $_value';

  set greeting(String value) => _value = value;

  // ignore: unused_element
  static String helper() => 'static';

  String _hidden() => _value;
}

class _Failing {
  _Failing() {
    throw StateError('cannot connect');
  }
}
