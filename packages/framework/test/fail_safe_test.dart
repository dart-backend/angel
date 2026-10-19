import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

bool deny(RequestContext req, ResponseContext res) =>
    throw AngelHttpException.forbidden();

@Middleware([deny])
class SecretService extends Service {
  @override
  Future<List> index([params]) async => ['secret'];
}

@Expose('/hidden')
class HiddenController extends Controller {
  String index() => 'hidden';
}

/// What fails safe: a class the reflector does not describe, a failure after
/// the headers are sent, and an error of a response whose `done` is awaited.
void main() {
  group('a class the reflector does not describe', () {
    late Angel app;
    late List<String> warnings;

    void start(Reflector reflector) {
      app = Angel(reflector: reflector);
      warnings = [];
      app.logger = Logger.detached('test')
        ..onRecord
            .where((r) => r.level == Level.WARNING)
            .listen((r) => warnings.add(r.message));
    }

    test('of a service is warned about, once', () {
      start(const StaticReflector());
      app.use('/secret', SecretService());
      app.use('/again', SecretService());
      expect(warnings.where((w) => w.contains('SecretService')), hasLength(1));
      expect(warnings.single, contains('@Middleware'));
      expect(warnings.single, contains('@injectable'));
    });

    test('of a controller is warned about', () async {
      start(const StaticReflector());
      await app.configure(HiddenController().configureServer);
      expect(warnings.single, contains('HiddenController'));
    });

    test('is not warned about for a MapService, nor without reflection', () {
      start(const StaticReflector());
      app.use('/items', MapService());
      expect(warnings, isEmpty);

      start(const ThrowingReflector());
      app.use('/secret', SecretService());
      expect(warnings, isEmpty);

      start(const EmptyReflector());
      app.use('/secret', SecretService());
      expect(warnings, isEmpty);
    });
  });

  group('a failure after the headers are sent', () {
    late AngelHttp http;
    late HttpServer server;

    setUp(() async {
      var app = Angel();
      app.logger = Logger.detached('test');
      app.get('/boom', (req, res) async {
        res.write('partial');
        await Future.delayed(const Duration(milliseconds: 20));
        throw StateError('boom');
      });
      http = AngelHttp(app);
      server = await http.startServer();
    });

    tearDown(() => http.close());

    test('aborts the response, rather than appending an error', () async {
      var client = HttpClient();
      try {
        var rs = await (await client.get(
          server.address.address,
          server.port,
          '/boom',
        )).close();
        expect(rs.statusCode, 200);
        await expectLater(
          rs.transform(utf8.decoder).join(),
          throwsA(isA<HttpException>()),
        );
      } finally {
        client.close();
      }
    });
  });

  group('an error added to a response', () {
    late Angel app;
    late List<String> severe;
    late AngelHttp http;
    late HttpServer server;

    setUp(() async {
      app = Angel();
      severe = [];
      app.logger = Logger.detached('test')
        ..onRecord
            .where((r) => r.level >= Level.SEVERE)
            .listen((r) => severe.add('${r.message} ${r.error}'));
      http = AngelHttp(app);
    });

    tearDown(() => http.close());

    Future<Object?> get(String path) async {
      server = await http.startServer();
      var client = HttpClient();
      try {
        var rs = await (await client.get(
          server.address.address,
          server.port,
          path,
        )).close();
        return await rs.transform(utf8.decoder).join();
      } catch (e) {
        return e;
      } finally {
        client.close();
      }
    }

    test(
      'fails the response, and is not uncaught if done is awaited',
      () async {
        var seen = Completer<Object?>();
        app.get('/', (req, res) async {
          var done = res.done.then<Object?>(
            (_) => null,
            onError: (Object e) => e,
          );
          res.write('partial');
          res.addError(StateError('handled'), StackTrace.current);
          seen.complete(await done);
          return false;
        });
        expect(await get('/'), isA<HttpException>());
        expect(
          await seen.future.timeout(const Duration(seconds: 3)),
          isA<StateError>(),
        );
        expect(severe, isEmpty);
      },
    );

    test('is handled as an error if nothing awaits done', () async {
      app.get('/', (req, res) {
        res.write('partial');
        res.addError(StateError('unhandled'), StackTrace.current);
        return false;
      });
      expect(await get('/'), isA<HttpException>());
      expect(severe, isNotEmpty);
    });
  });
}
