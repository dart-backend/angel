import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:test/test.dart';

/// Invalid response headers set by the app, over a real HTTP/1.1 server.
void main() {
  late AngelHttp http;
  late HttpClient client;

  setUp(() async {
    var app = Angel()
      ..get('/bad-value', (req, res) {
        res.headers['x-name'] = 'café';
        return 'body';
      })
      ..get('/bad-name', (req, res) {
        res.headers['bad name'] = 'x';
        return 'body';
      })
      ..get('/bad-buffered', (req, res) {
        res
          ..useBuffer()
          ..headers['x-name'] = 'line\r\nbreak'
          ..write('body');
      })
      ..get('/caught', (req, res) {
        // Rejected where it is set, so the handler can recover.
        try {
          res.headers['x-name'] = 'café';
        } on AngelHttpException {
          res.headers['x-rejected'] = 'yes';
        }
        return 'body';
      })
      ..get('/bypass', (req, res) {
        // putIfAbsent skips the setter; the send-time check catches it.
        res.headers.putIfAbsent('x-name', () => 'café');
        return 'body';
      })
      ..get('/good', (req, res) {
        res.headers['x-name'] = 'plain value\twith tab';
        return 'body';
      });
    http = AngelHttp(app);
    await http.startServer('127.0.0.1', 0);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await http.close();
  });

  Future<(HttpClientResponse, String)> get(String path) async {
    var rq = await client.getUrl(http.uri.replace(path: path));
    rq.headers.set('accept', 'application/json');
    var rs = await rq.close();
    return (rs, await rs.transform(utf8.decoder).join());
  }

  test('an invalid header is rejected when set, and not stored', () async {
    var (rs, body) = await get('/caught');
    expect(rs.statusCode, 200);
    expect(rs.headers.value('x-rejected'), 'yes');
    expect(rs.headers.value('x-name'), isNull);
    expect(json.decode(body), 'body');
  });

  for (var path in ['/bad-value', '/bad-name', '/bad-buffered', '/bypass']) {
    test('$path fails with a 500 naming the header', () async {
      var (rs, body) = await get(path);
      expect(rs.statusCode, 500);
      expect(json.decode(body)['message'], contains('Invalid response header'));
    });
  }

  test('valid headers are sent', () async {
    var (rs, body) = await get('/good');
    expect(rs.statusCode, 200);
    expect(rs.headers.value('x-name'), 'plain value\twith tab');
    expect(json.decode(body), 'body');
  });

  group('validators', () {
    test('isValidHeaderValue', () {
      expect(ResponseContext.isValidHeaderValue('text/html; q=1'), isTrue);
      expect(ResponseContext.isValidHeaderValue('a\tb'), isTrue);
      expect(ResponseContext.isValidHeaderValue(''), isTrue);
      expect(ResponseContext.isValidHeaderValue('café'), isFalse);
      expect(ResponseContext.isValidHeaderValue('日本'), isFalse);
      expect(ResponseContext.isValidHeaderValue('a\r\nb'), isFalse);
    });

    test('isValidHeaderName', () {
      expect(ResponseContext.isValidHeaderName('x-custom_1'), isTrue);
      expect(ResponseContext.isValidHeaderName(''), isFalse);
      expect(ResponseContext.isValidHeaderName('bad name'), isFalse);
      expect(ResponseContext.isValidHeaderName('a:b'), isFalse);
    });
  });
}
