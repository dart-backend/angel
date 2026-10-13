import 'dart:convert';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

/// Injection with a [StaticReflector] that knows only the handlers, not
/// [Parameter] or the types of their parameters, as generated reflectors may.
class _Type extends ReflectedType {
  _Type(Type type) : super(type.toString(), const [], type);

  @override
  bool isAssignableTo(ReflectedType? other) =>
      other?.reflectedType == reflectedType;

  @override
  ReflectedInstance newInstance(
    String constructorName,
    List positionalArguments, [
    Map<String, dynamic> namedArguments = const {},
    List<Type> typeArguments = const [],
  ]) => throw UnsupportedError('Not needed by these tests.');
}

class _Function extends ReflectedFunction {
  const _Function(List<ReflectedParameter> parameters)
    : super('handler', const [], const [], parameters, false, false);

  @override
  ReflectedInstance invoke(Invocation invocation) =>
      throw UnsupportedError('Not needed by these tests.');
}

class _Unregistered {}

class _HealthController extends Controller {
  _HealthController() : super(expose: const Expose('/health'));

  @override
  void configureRoutes(Routable routable) {
    routable.get('/', (req, res) => 'ok');
  }
}

void main() {
  Future<(int, String)> get(Angel app, String path) async {
    var rq = MockHttpRequest('GET', Uri.parse(path))
      ..headers.set('accept', 'application/json');
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    var body = await rq.response.transform(utf8.decoder).join();
    return (rq.response.statusCode, body);
  }

  test(
    'a handler without parameters needs no information about Parameter',
    () async {
      String handler() => 'hi';
      var app = Angel(
        reflector: StaticReflector(functions: {handler: const _Function([])}),
      )..get('/', ioc(handler));
      expect(await get(app, '/'), (200, json.encode('hi')));
    },
  );

  test(
    'a parameter without annotations needs no information about Parameter',
    () async {
      String handler(String name) => 'hi $name';
      var app = Angel(
        reflector: StaticReflector(
          functions: {
            handler: _Function([
              ReflectedParameter('name', [], _Type(String), true, false),
            ]),
          },
        ),
      )..get('/hi/:name', ioc(handler));
      expect(await get(app, '/hi/bob'), (200, json.encode('hi bob')));
    },
  );

  test(
    'an optional parameter the reflector cannot construct is left out',
    () async {
      String handler({_Unregistered? dep}) => 'dep: $dep';
      var app = Angel(
        reflector: StaticReflector(
          functions: {
            handler: _Function([
              ReflectedParameter('dep', [], _Type(_Unregistered), false, true),
            ]),
          },
        ),
      )..get('/', ioc(handler));
      expect(await get(app, '/'), (200, json.encode('dep: null')));
    },
  );

  group('a controller', () {
    Future<void> expectRoutes(Reflector reflector) async {
      var app = Angel(reflector: reflector);
      await app.configure(_HealthController().configureServer);
      expect(await get(app, '/health'), (200, json.encode('ok')));
      expect(app.controllers.keys, contains('_HealthController'));
    }

    test('the reflector knows nothing about uses its configureRoutes', () {
      return expectRoutes(StaticReflector());
    });

    test('known to the reflector only as a class (as @injectable data is) '
        'uses its configureRoutes', () {
      return expectRoutes(
        StaticReflector(
          types: {
            _HealthController: StaticReflectedClass(
              '_HealthController',
              _HealthController,
              create: (p, n) => _HealthController(),
            ),
          },
        ),
      );
    });
  });
}
