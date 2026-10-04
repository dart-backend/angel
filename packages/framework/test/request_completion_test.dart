import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

/// `handleRequest` must complete once the response has been sent, including
/// when a handler throws (which is handled inside the request's error zone).
void main() {
  for (var useZone in [true, false]) {
    group(useZone ? 'with zone' : 'without zone', () {
      late Angel app;
      late AngelHttp http;

      setUp(() {
        app = Angel()
          ..get('/ok', (req, res) => 'ok')
          ..get('/sync-throw', (req, res) => throw StateError('boom'))
          ..get('/async-throw', (req, res) async {
            await Future<void>.delayed(Duration.zero);
            throw StateError('boom');
          })
          ..get(
            '/http-error',
            (req, res) => throw AngelHttpException.forbidden(),
          )
          ..get('/ioc', ioc((String unresolved) => unresolved));
        http = AngelHttp(app, useZone: useZone);
      });

      tearDown(() => http.close());

      Future<(int, String)> send(String path) async {
        var rq = MockHttpRequest('GET', Uri(path: path))
          ..headers.set('accept', 'application/json');
        await rq.close();
        await http
            .handleRequest(rq)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => fail('handleRequest did not complete'),
            );
        var body = await rq.response.transform(utf8.decoder).join();
        return (rq.response.statusCode, body);
      }

      test('completes after a normal response', () async {
        var (status, body) = await send('/ok');
        expect(status, 200);
        expect(body, json.encode('ok'));
      });

      for (var (path, expected) in [
        ('/sync-throw', 500),
        ('/async-throw', 500),
        ('/http-error', 403),
        ('/ioc', 500),
      ]) {
        test('completes after the error response for $path', () async {
          var (status, body) = await send(path);
          expect(status, expected);
          expect(json.decode(body)['status_code'], expected);
        });
      }
    });
  }
}
