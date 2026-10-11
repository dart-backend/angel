import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

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

void main() {
  test('no info-level log line per request', () async {
    var records = <LogRecord>[];
    var logger = Logger.detached('quiet')..level = Level.ALL;
    logger.onRecord.listen(records.add);
    var app = Angel(logger: logger)..get('/', (req, res) => 'ok');
    records.clear(); // Only the request matters, not startup messages.

    var rq = MockHttpRequest('GET', Uri(path: '/'));
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    await rq.response.drain<void>();

    expect(records.where((r) => r.level >= Level.INFO), isEmpty);
  });

  group('controller verb inference', () {
    late AngelHttp http;

    setUp(() async {
      var app = Angel(reflector: MirrorsReflector());
      await app.configure(ItemController().configureServer);
      http = AngelHttp(app);
    });

    Future<(int, String)> send(String method, String path) async {
      var rq = MockHttpRequest(method, Uri(path: path))
        ..headers.set('accept', 'application/json');
      await rq.close();
      await http.handleRequest(rq);
      var body = await rq.response.transform(utf8.decoder).join();
      return (rq.response.statusCode, body);
    }

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

  group('HEAD', () {
    late AngelHttp http;

    setUp(() async {
      var api = Angel()..get('/users/:id', (req, res) => 'user');
      var app = Angel()
        ..all('*', (req, res) {
          res.headers['x-middleware'] = 'ran';
          return true;
        })
        ..get('/page', (req, res) {
          res.headers['x-handler'] = 'get';
          return {'large': 'body'};
        })
        ..get('/explicit', (req, res) => 'get')
        ..addRoute('HEAD', '/explicit', (req, res) {
          res.headers['x-handler'] = 'head';
          return res.close();
        })
        ..post('/post-only', (req, res) => 'post')
        ..fallback(HostnameRouter(apps: {'api.example.com': api}).handleRequest)
        ..fallback((req, res) => throw AngelHttpException.notFound());
      http = AngelHttp(app);
      await http.startServer('127.0.0.1', 0);
    });

    tearDown(() => http.close());

    /// Sends a raw HEAD request, so any body bytes would be visible.
    Future<(int, Map<String, String>, int)> head(
      String path, {
      String host = 'localhost',
    }) async {
      var socket = await Socket.connect('127.0.0.1', http.uri.port);
      socket.write(
        'HEAD $path HTTP/1.1\r\nHost: $host\r\n'
        'Accept: application/json\r\nConnection: close\r\n\r\n',
      );
      var bytes = <int>[];
      await socket.listen(bytes.addAll).asFuture<void>();
      socket.destroy();

      var text = latin1.decode(bytes);
      var end = text.indexOf('\r\n\r\n');
      var lines = text.substring(0, end).split('\r\n');
      var status = int.parse(lines.first.split(' ')[1]);
      var headers = {
        for (var line in lines.skip(1))
          line.substring(0, line.indexOf(':')).toLowerCase(): line
              .substring(line.indexOf(':') + 1)
              .trim(),
      };
      return (status, headers, bytes.length - end - 4);
    }

    test('is answered by the GET handler, without a body', () async {
      var (status, headers, bodyBytes) = await head('/page');
      expect(status, 200);
      expect(headers['x-handler'], 'get');
      expect(headers['x-middleware'], 'ran');
      expect(bodyBytes, 0);
    });

    test('an explicit HEAD route takes precedence', () async {
      var (status, headers, _) = await head('/explicit');
      expect(status, 200);
      expect(headers['x-handler'], 'head');
    });

    test('still 404s when no GET route matches', () async {
      expect((await head('/missing')).$1, 404);
      expect((await head('/post-only')).$1, 404);
    });

    test('works through HostnameRouter sub-apps', () async {
      var (status, _, bodyBytes) = await head(
        '/users/1',
        host: 'api.example.com',
      );
      expect(status, 200);
      expect(bodyBytes, 0);
    });
  });

  test('buffered responses work for HTTP/1.0 clients', () async {
    var app = Angel()
      ..get('/', (req, res) {
        res
          ..useBuffer()
          ..write('buffered');
        return res.close();
      });
    var http = AngelHttp(app);
    await http.startServer('127.0.0.1', 0);
    addTearDown(http.close);

    var socket = await Socket.connect('127.0.0.1', http.uri.port);
    socket.write('GET / HTTP/1.0\r\n\r\n');
    var bytes = <int>[];
    await socket.listen(bytes.addAll).asFuture<void>();
    socket.destroy();

    var text = latin1.decode(bytes);
    expect(text, startsWith('HTTP/1.0 200'));
    expect(text.toLowerCase(), contains('content-length: 8'));
    expect(text, endsWith('\r\n\r\nbuffered'));
  });
}
