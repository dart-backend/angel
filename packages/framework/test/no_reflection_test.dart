import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

import 'common.dart';

/// Everything here runs on an `Angel()` with no reflector (the default),
/// i.e. the configuration used by AOT-compiled apps without `dart:mirrors`.
void main() {
  late Angel app;
  late AngelHttp http;

  setUp(() {
    app = Angel();
    http = AngelHttp(app);
  });

  tearDown(() => http.close());

  Future<(int, dynamic)> send(
    String method,
    String path, {
    Object? body,
  }) async {
    var rq = MockHttpRequest(method, Uri(path: path))
      ..headers.set('accept', 'application/json');
    if (body != null) {
      rq
        ..headers.set('content-type', 'application/json')
        ..write(json.encode(body));
    }
    await rq.close();
    // Wait on the response rather than handleRequest: when a handler throws,
    // the zone-based error path sends the 500 but never completes that future.
    unawaited(http.handleRequest(rq));
    var text = await rq.response.transform(utf8.decoder).join();
    return (rq.response.statusCode, text.isEmpty ? null : json.decode(text));
  }

  group('services', () {
    test('can be mounted and used over REST', () async {
      app.use('/todos', MapService());

      var (createStatus, created) = await send(
        'POST',
        '/todos',
        body: {'text': 'clean'},
      );
      expect(createStatus, 201);
      expect(created['text'], 'clean');

      var (_, all) = await send('GET', '/todos');
      expect(all, hasLength(1));
    });

    test('fire hooked events', () async {
      var hooked = app.use('/todos', MapService());
      var events = <String>[];
      hooked.beforeCreated.listen((e) => events.add('before'));
      hooked.afterCreated.listen((e) => events.add('after'));

      await send('POST', '/todos', body: {'text': 'clean'});
      expect(events, ['before', 'after']);
    });
  });

  group('controllers', () {
    test('use explicit expose and configureRoutes', () async {
      await app.configure(_TodoController().configureServer);

      var (status, body) = await send('GET', '/api/todos/hello');
      expect(status, 200);
      expect(body, 'hello');
      expect(app.controllers['todos'], isA<_TodoController>());
    });

    test('derive mount path from class name without expose', () async {
      await app.configure(PlainController().configureServer);

      var (status, body) = await send('GET', '/plain/ping');
      expect(status, 200);
      expect(body, 'pong');
    });

    test('can be mounted from the container', () async {
      app.container.registerSingleton(_TodoController());
      var controller = await app.mountController<_TodoController>();
      expect(controller.mountPoint, isNotNull);
    });
  });

  group('ioc', () {
    test('injects from an explicit InjectionRequest', () async {
      app.container.registerSingleton(Todo(text: 'Hey!'));
      app.get(
        '/todo/:id',
        ioc(
          (RequestContext req, Todo todo, String id) => '${todo.text} $id',
          injection: InjectionRequest.constant(
            required: [
              RequestContext,
              Todo,
              ['id', String],
            ],
          ),
        ),
      );

      var (status, body) = await send('GET', '/todo/7');
      expect(status, 200);
      expect(body, 'Hey! 7');
    });

    test('merges optional names into a const InjectionRequest', () async {
      app.get(
        '/optional',
        ioc(
          (String? missing) => missing ?? 'none',
          injection: const InjectionRequest.constant(required: ['missing']),
          optional: ['missing'],
        ),
      );

      var (status, body) = await send('GET', '/optional');
      expect(status, 200);
      expect(body, 'none');
    });

    test('without an InjectionRequest fails clearly', () async {
      app.get('/reflect', ioc((Todo todo) => todo.text));

      var (status, body) = await send('GET', '/reflect');
      expect(status, 500);
      expect(body['message'], contains('ThrowingReflector'));
    });
  });
}

class _TodoController extends Controller {
  _TodoController() : super(expose: const Expose('/api/todos', as: 'todos'));

  @override
  void configureRoutes(Routable routable) {
    routable.get('/hello', (req, res) => 'hello');
  }
}

class PlainController extends Controller {
  @override
  void configureRoutes(Routable routable) {
    routable.get('/ping', (req, res) => 'pong');
  }
}
