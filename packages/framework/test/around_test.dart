import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// Handlers made by `around`, which run around the handlers after them of a
/// route's pipeline, with `next` (issue 174).
void main() {
  for (var production in [false, true]) {
    for (var useZone in [false, true]) {
      group(
        '${production ? 'production' : 'development'}, '
        '${useZone ? 'in a zone' : 'without a zone'}',
        () => _tests(production: production, useZone: useZone),
      );
    }
  }

  test('outside a pipeline, next runs nothing', () async {
    var app = Angel(logger: Logger.detached('test'));
    var rq = MockHttpRequest('GET', Uri(path: '/'));
    await rq.close();
    var http = AngelHttp(app);
    var req = await http.createRequestContext(rq, rq.response);
    var res = await http.createResponseContext(rq, rq.response, req);
    var ran = <String>[];
    var calls = around((req, res, next) async {
      ran.add('before');
      await next();
      ran.add('after');
    });
    var stops = around((req, res, next) {});
    expect(await app.executeHandler(calls, req, res), isTrue);
    expect(await app.executeHandler(stops, req, res), isFalse);
    expect(ran, ['before', 'after']);
  });
}

void _tests({required bool production, required bool useZone}) {
  late Angel app;
  late AngelHttp http;
  late List<String> ran;
  late List<Object> errors;

  setUp(() {
    ran = [];
    errors = [];
    app = Angel(
      environment: AngelEnvironment(production ? 'production' : 'development'),
      logger: Logger.detached('test'),
    );
    app.errorHandler = (e, req, res) {
      errors.add(e.error ?? e);
      res.statusCode = e.statusCode;
      res.write('error');
    };
    http = AngelHttp(app, useZone: useZone);
  });

  Future<(int, String)> get(String path) async {
    if (production) app.optimizeForProduction(force: true);
    var rq = MockHttpRequest('GET', Uri(path: path));
    await rq.close();
    await http.handleRequest(rq);
    var body = await rq.response.transform(utf8.decoder).join();
    return (rq.response.statusCode, body);
  }

  /// An around handler of [name], which records its parts in [ran].
  RequestHandler wrap(String name) => around((req, res, next) async {
    ran.add('$name before');
    try {
      await next();
    } finally {
      ran.add('$name after');
    }
  });

  RequestHandler step(String name, [Object? result = true]) => (req, res) {
    ran.add(name);
    return result;
  };

  test('runs around the handlers after it, before the response', () async {
    app
      ..fallback(wrap('outer'))
      ..get('/', (req, res) {
        ran.add('handler');
        res.write('ok');
      });
    var (status, body) = await get('/');
    expect((status, body), (200, 'ok'));
    expect(ran, ['outer before', 'handler', 'outer after']);
  });

  test('wraps the handlers of the routes after its own', () async {
    app
      ..fallback(wrap('global'))
      ..chain([wrap('chained'), step('middleware')])
          .get('/', step('handler', 'done'), middleware: [wrap('route')]);
    var (status, body) = await get('/');
    expect(status, 200);
    expect(json.decode(body), 'done');
    expect(ran, [
      'global before',
      'chained before',
      'middleware',
      'route before',
      'handler',
      'route after',
      'chained after',
      'global after',
    ]);
  });

  test('stops the pipeline if it does not call next', () async {
    app
      ..fallback(
        around((req, res, next) {
          ran.add('guard');
          res
            ..statusCode = 403
            ..write('no');
        }),
      )
      ..get('/', step('handler', 'yes'));
    expect(await get('/'), (403, 'no'));
    expect(ran, ['guard']);
  });

  test('stops where a handler after it does', () async {
    app
      ..fallback(wrap('outer'))
      ..fallback(step('stop', false))
      ..get('/', step('handler'));
    await get('/');
    expect(ran, ['outer before', 'stop', 'outer after']);
  });

  test('catches the error of a handler after it, as to roll back', () async {
    app
      ..fallback(
        around((req, res, next) async {
          try {
            await next();
            ran.add('commit');
          } catch (e) {
            ran.add('rollback');
            rethrow;
          }
        }),
      )
      ..get('/', (req, res) => throw StateError('failed'))
      ..get('/ok', step('handler'));
    var (status, body) = await get('/');
    expect((status, body), (500, 'error'));
    expect(ran, ['rollback']);
    // The app's error handler is given it, as a 500.
    expect('${errors.single}', contains('failed'));

    ran.clear();
    await get('/ok');
    expect(ran, ['handler', 'commit']);
  });

  test('may answer the error itself', () async {
    app
      ..fallback(
        around((req, res, next) async {
          try {
            await next();
          } on StateError {
            res
              ..statusCode = 409
              ..write('conflict');
          }
        }),
      )
      ..get('/', (req, res) => throw StateError('failed'));
    expect(await get('/'), (409, 'conflict'));
    expect(errors, isEmpty);
  });

  test('gives the handlers after it what it registers', () async {
    // As a transaction's executor, of the request's container.
    app
      ..fallback(
        around((req, res, next) async {
          req.container!.registerSingleton<String>('tx-1');
          await next();
        }),
      )
      ..get('/', (req, res) => req.container!.make<String>());
    expect(await get('/'), (200, '"tx-1"'));
  });

  test('rewrites a buffered body after the handlers', () async {
    app
      ..fallback(
        around((req, res, next) async {
          res.useBuffer();
          await next();
          var data = utf8.decode(res.buffer!.takeBytes());
          res.buffer!.add(utf8.encode('{"data":$data}'));
        }),
      )
      // Writes without closing the response, whose buffer stays open.
      ..get('/', (req, res) => res.write('{"a":1}'));
    var (status, body) = await get('/');
    expect(status, 200);
    expect(json.decode(body), {
      'data': {'a': 1},
    });
  });

  test('a handler that closes the response locks its buffer', () async {
    // As the docs tell: such a body is rewritten by a finalizer.
    Object? error;
    app
      ..fallback(
        around((req, res, next) async {
          res.useBuffer();
          await next();
          try {
            res.buffer!.add(utf8.encode('more'));
          } catch (e) {
            error = e;
          }
        }),
      )
      ..get('/', (req, res) => {'a': 1});
    var (status, body) = await get('/');
    expect(status, 200);
    expect(json.decode(body), {'a': 1});
    expect(error, isStateError);
  });

  test('an error of a next it did not wait for is the request\'s', () async {
    app
      ..fallback(
        around((req, res, next) {
          unawaited(next());
        }),
      )
      ..get('/', (req, res) async {
        await Future.delayed(const Duration(milliseconds: 10));
        throw StateError('late failure');
      });
    var (status, _) = await get('/');
    expect(status, 500);
    expect('${errors.single}', contains('late failure'));
  });

  test('waits for a next it does not await', () async {
    app
      ..fallback(
        around((req, res, next) {
          unawaited(next());
        }),
      )
      ..get('/', (req, res) async {
        await Future.delayed(const Duration(milliseconds: 10));
        res.write('late');
      });
    expect(await get('/'), (200, 'late'));
  });

  test('is an error to call next twice', () async {
    app
      ..fallback(
        around((req, res, next) async {
          await next();
          await next();
        }),
      )
      ..get('/', step('handler'));
    var (status, _) = await get('/');
    expect(status, 500);
    expect(ran, ['handler']);
    expect('${errors.single}', contains('next() was called more than once'));
  });

  test('is an error to call next after it completes', () async {
    late Future<void> Function() kept;
    app
      ..fallback(
        around((req, res, next) {
          kept = next;
          res.write('done');
        }),
      )
      ..get('/', step('handler'));
    expect(await get('/'), (200, 'done'));
    expect(kept, throwsStateError);
    expect(ran, isEmpty);
  });

  test('runs code once the response is sent, with res.done', () async {
    var sent = Completer<int>();
    app
      ..fallback(
        around((req, res, next) async {
          res.done.then((_) => sent.complete(res.statusCode));
          await next();
        }),
      )
      ..get('/', (req, res) {
        res.statusCode = 201;
        res.write('made');
      });
    expect(await get('/'), (201, 'made'));
    expect(await sent.future, 201);
  });

  test('in chain, runs around the rest of the chain', () async {
    app.get(
      '/',
      chain([wrap('in chain'), step('first'), step('second')]),
      middleware: [],
    );
    await get('/');
    expect(ran, ['in chain before', 'first', 'second', 'in chain after']);
  });

  test('leaves a pipeline of no around handlers as it was', () async {
    app
      ..fallback(step('first'))
      ..fallback(step('stop', false))
      ..get('/', step('handler'));
    await get('/');
    expect(ran, ['first', 'stop']);
  });
}
