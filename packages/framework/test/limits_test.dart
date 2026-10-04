import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  group('maxBodySize', () {
    late Angel app;
    late AngelHttp http;

    setUp(() {
      app = Angel()
        ..post('/echo', (req, res) async {
          await req.parseBody();
          return req.bodyAsMap;
        })
        ..post('/upload', (req, res) async {
          await req.parseBody();
          return req.uploadedFiles!.length;
        });
      http = AngelHttp(app);
    });

    Future<int> post(
      String path,
      String body, {
      String contentType = 'application/json',
      int? declaredLength,
    }) async {
      var rq = MockHttpRequest('POST', Uri(path: path))
        ..headers.set('accept', 'application/json')
        ..headers.set('content-type', contentType)
        ..write(body);
      if (declaredLength != null) rq.headers.contentLength = declaredLength;
      await rq.close();
      // When a handler throws, handleRequest never completes; wait on the
      // response instead.
      unawaited(http.handleRequest(rq));
      await rq.response.drain<void>();
      return rq.response.statusCode;
    }

    String jsonOfSize(int bytes) {
      var prefix = '{"a":"';
      var suffix = '"}';
      return '$prefix${'x' * (bytes - prefix.length - suffix.length)}$suffix';
    }

    test('defaults to 10 MB', () {
      expect(app.maxBodySize, 10 * 1024 * 1024);
      expect(Angel.defaultMaxBodySize, 10 * 1024 * 1024);
    });

    test('accepts a body at the limit', () async {
      app.maxBodySize = 100;
      expect(await post('/echo', jsonOfSize(100)), 200);
    });

    test('rejects a larger body by counting bytes', () async {
      app.maxBodySize = 100;
      expect(await post('/echo', jsonOfSize(101)), 413);
    });

    test('rejects early on a declared Content-Length', () async {
      app.maxBodySize = 100;
      expect(await post('/echo', '{}', declaredLength: 1000), 413);
    });

    test('rejects a body that understates its Content-Length', () async {
      app.maxBodySize = 100;
      expect(await post('/echo', jsonOfSize(500), declaredLength: 10), 413);
    });

    test('applies to multipart uploads', () async {
      app.maxBodySize = 100;
      var boundary = 'XYZ';
      var body =
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="a.bin"\r\n'
          'Content-Type: application/octet-stream\r\n\r\n'
          '${'x' * 500}\r\n'
          '--$boundary--\r\n';
      expect(
        await post(
          '/upload',
          body,
          contentType: 'multipart/form-data; boundary=$boundary',
        ),
        413,
      );
    });

    test('null means unlimited', () async {
      app.maxBodySize = null;
      expect(await post('/echo', jsonOfSize(20 * 1024 * 1024)), 200);
    });

    test('can be raised per route by middleware', () async {
      app.maxBodySize = 100;
      app.post('/big', (req, res) async {
        await req.parseBody();
        return req.bodyAsMap.length;
      }, middleware: [(req, res) => (req.maxBodySize = 1000) > 0]);

      expect(await post('/big', jsonOfSize(500)), 200);
      expect(await post('/echo', jsonOfSize(500)), 413);
    });
  });

  group('handlerCache', () {
    late Angel app;
    late AngelHttp http;

    setUp(() {
      app = Angel(environment: AngelEnvironment('production'))
        ..get('/users/:id', (req, res) => 'user ${req.params['id']}')
        ..get('/a', (req, res) => 'a');
      http = AngelHttp(app);
    });

    Future<String> get(String path) async {
      var rq = MockHttpRequest('GET', Uri(path: path));
      await rq.close();
      unawaited(http.handleRequest(rq));
      return await rq.response.transform(utf8.decoder).join();
    }

    test('is bounded by maxHandlerCacheSize', () async {
      app.maxHandlerCacheSize = 3;
      for (var i = 0; i < 20; i++) {
        expect(await get('/users/$i'), json.encode('user $i'));
      }
      expect(app.handlerCache, hasLength(3));
    });

    test('evicts the least recently used entry', () async {
      app.maxHandlerCacheSize = 2;
      await get('/a');
      await get('/users/1');
      await get('/a'); // /a is now the most recently used
      await get('/users/2'); // evicts /users/1

      expect(app.handlerCache.keys, unorderedEquals(['GETa', 'GETusers/2']));
    });

    test('is disabled when maxHandlerCacheSize is 0', () async {
      app.maxHandlerCacheSize = 0;
      expect(await get('/users/1'), json.encode('user 1'));
      expect(app.handlerCache, isEmpty);
    });
  });
}
