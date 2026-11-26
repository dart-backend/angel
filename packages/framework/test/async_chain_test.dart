import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// How the request pipeline runs handlers that give their results at once,
/// and later, and how a request and its response close.
void main() {
  for (var useZone in [false, true]) {
    group(useZone ? 'in a zone' : 'without a zone', () {
      late Angel app;
      late AngelHttp http;
      late List<String> ran;

      setUp(() {
        ran = [];
        app = Angel(
          environment: const AngelEnvironment('production'),
          logger: Logger.detached('test'),
        );
        http = AngelHttp(app, useZone: useZone);
      });

      Future<(int, String)> get(String path) async {
        app.optimizeForProduction(force: true);
        var rq = MockHttpRequest('GET', Uri(path: path))
          ..headers.set('accept', 'application/json');
        await rq.close();
        await http.handleRequest(rq);
        var body = await rq.response.transform(utf8.decoder).join();
        return (rq.response.statusCode, body);
      }

      RequestHandler step(String name, Object? result) => (req, res) {
        ran.add(name);
        return result;
      };

      RequestHandler asyncStep(String name, Object? result) =>
          (req, res) async {
            await Future<void>.delayed(Duration.zero);
            ran.add(name);
            return result;
          };

      test('runs handlers that give their results at once, in order', () async {
        app.get(
          '/a',
          step('handler', 'done'),
          middleware: [step('one', true), step('two', true)],
        );
        expect(await get('/a'), (200, '"done"'));
        expect(ran, ['one', 'two', 'handler']);
      });

      test('runs handlers that give some results later, in order', () async {
        app.get(
          '/a',
          step('handler', 'done'),
          middleware: [
            step('one', true),
            asyncStep('two', true),
            step('three', true),
            asyncStep('four', true),
          ],
        );
        expect(await get('/a'), (200, '"done"'));
        expect(ran, ['one', 'two', 'three', 'four', 'handler']);
      });

      for (var (kind, make) in [('at once', step), ('later', asyncStep)]) {
        test('a handler that gives false $kind stops the pipeline', () async {
          app.get(
            '/a',
            step('handler', 'done'),
            middleware: [
              step('one', true),
              (req, res) {
                res.write('stopped');
                return make('two', false)(req, res);
              },
            ],
          );
          expect(await get('/a'), (200, 'stopped'));
          expect(ran, ['one', 'two']);
        });

        test('a handler that gives null $kind stops the pipeline', () async {
          app.get(
            '/a',
            step('handler', 'done'),
            middleware: [make('one', null)],
          );
          expect((await get('/a')).$1, 200);
          expect(ran, ['one']);
        });
      }

      // As angel3_openapi does: serialize writes a microtask later, which the
      // pipeline must wait for before it sends the response.
      test('a handler may stop without waiting for res.json', () async {
        app.get('/a', (req, res) {
          res.json({'a': 1});
          return false;
        });
        expect(await get('/a'), (200, '{"a":1}'));
      });

      test('middleware may go on without waiting for res.json', () async {
        app.get(
          '/a',
          (req, res) => res.isOpen ? 'not sent' : null,
          middleware: [
            (req, res) {
              res.json({'a': 1});
              return true;
            },
          ],
        );
        expect(await get('/a'), (200, '{"a":1}'));
      });

      test('a handler that throws at once gives a 500', () async {
        app.get(
          '/a',
          step('handler', 'done'),
          middleware: [
            step('one', true),
            (req, res) => throw StateError('at once'),
          ],
        );
        var (status, body) = await get('/a');
        expect(status, 500);
        expect(body, contains('at once'));
        expect(ran, ['one']);
      });

      test('a handler that throws later gives a 500', () async {
        app.get(
          '/a',
          step('handler', 'done'),
          middleware: [
            step('one', true),
            (req, res) async {
              await Future<void>.delayed(Duration.zero);
              throw StateError('later');
            },
          ],
        );
        var (status, body) = await get('/a');
        expect(status, 500);
        expect(body, contains('later'));
        expect(ran, ['one']);
      });

      test('the request is closed, and its shutdown hooks run', () async {
        app.get('/a', (req, res) {
          req.shutdownHooks
            ..add(() => ran.add('hook one'))
            ..add(() async {
              await Future<void>.delayed(Duration.zero);
              ran.add('hook two');
            });
          return 'done';
        });
        expect(await get('/a'), (200, '"done"'));
        expect(ran, ['hook one', 'hook two']);
      });
    });
  }

  group('Driver.runPipeline', () {
    late Angel app;
    late RequestContext req;
    late ResponseContext res;

    setUp(() async {
      app = Angel(logger: Logger.detached('test'));
      var http = AngelHttp(app);
      var rq = MockHttpRequest('GET', Uri(path: '/'));
      await rq.close();
      req = await http.createRequestContext(rq, rq.response);
      res = await http.createResponseContext(rq, rq.response);
    });

    MiddlewarePipelineIterator<RequestHandler> pipeline(
      List<RequestHandler> handlers,
    ) {
      var router = Router<RequestHandler>()
        ..get('/', handlers.last, middleware: handlers.sublist(0, 1));
      var results = router.resolveAbsolute('/');
      return MiddlewarePipelineIterator(MiddlewarePipeline(results));
    }

    test('fails its Future when a handler throws at once', () async {
      var it = pipeline([(req, res) => throw StateError('x'), (req, res) {}]);
      late Future<void> running;
      expect(
        () => running = Driver.runPipeline(it, req, res, app),
        returnsNormally,
      );
      await expectLater(running, throwsStateError);
    });

    test('completes when its handlers give their results at once', () async {
      var ran = <int>[];
      var it = pipeline([
        (req, res) {
          ran.add(1);
          return true;
        },
        (req, res) {
          ran.add(2);
        },
      ]);
      await Driver.runPipeline(it, req, res, app);
      expect(ran, [1, 2]);
    });
  });

  group('closing', () {
    late Angel app;
    late HttpRequestContext req;
    late HttpResponseContext res;

    setUp(() async {
      app = Angel(logger: Logger.detached('test'));
      var http = AngelHttp(app);
      var rq = MockHttpRequest('GET', Uri(path: '/'));
      await rq.close();
      req = await http.createRequestContext(rq, rq.response);
      res = await http.createResponseContext(rq, rq.response, req);
    });

    test('a request runs its shutdown hooks once, in order', () async {
      var ran = <String>[];
      req.shutdownHooks
        ..add(() async {
          await Future<void>.delayed(Duration.zero);
          ran.add('one');
        })
        ..add(() => ran.add('two'));
      await req.close();
      await req.close();
      expect(ran, ['one', 'two']);
    });

    test('a request shutdown hook that fails fails close', () async {
      req.shutdownHooks.add(() => throw StateError('hook'));
      await expectLater(req.close(), throwsStateError);
    });

    test('an invalid header fails close, rather than throwing', () async {
      res.headers.putIfAbsent('bad name', () => 'x');
      late Future<void> closing;
      expect(() => closing = res.close(), returnsNormally);
      await expectLater(closing, throwsA(isA<AngelHttpException>()));
      // Left open, for the error handler.
      expect(res.isOpen, isTrue);
    });

    test('a response closes once', () async {
      await res.close();
      expect(res.isOpen, isFalse);
      await res.close();
    });
  });
}
