import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

class _Point {
  final int x, y;
  _Point(this.x, this.y);
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

final _payload = {
  'hello': 'world',
  'unicode': 'café ünïcødé 日本 😀',
  'escapes': 'quote " backslash \\ newline \n tab \t',
  'numbers': [0, -1, 1.5, 1e21, null, true, false],
  'nested': {
    'list': [
      {'a': 1},
      [],
      {},
    ],
  },
};

void main() {
  late Angel app;
  late http.Client client;
  late HttpServer server;
  late String url;

  setUp(() async {
    app = Angel()
      ..get(
        '/foo',
        ioc(() => {'hello': 'world'}, injection: InjectionRequest.constant()),
      )
      ..get('/bar', (req, res) async {
        await res.serialize({
          'hello': 'world',
        }, contentType: MediaType('text', 'html'));
      })
      ..get('/payload', (req, res) => _payload)
      ..get('/to-json', (req, res) => [_Point(1, 2)])
      ..get('/buffered', (req, res) async {
        res.useBuffer();
        await res.json(_payload);
      })
      ..get('/custom', (req, res) async {
        res.serializer = (value) => 'custom:${json.encode(value)}';
        await res.json({'a': 1});
      })
      ..get('/unawaited', (req, res) {
        // Not awaited: the status set after it is still sent.
        res.json({'created': true});
        res.statusCode = 201;
        return false;
      })
      ..get('/unencodable', (req, res) => {'x': Object()});
    client = http.Client();

    server = await AngelHttp(app).startServer();
    url = 'http://${server.address.host}:${server.port}';
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  Future<http.Response> get(String path) => client.get(Uri.parse('$url$path'));

  test('correct content-type', () async {
    var response = await get('/foo');
    expect(response.headers['content-type'], contains('application/json'));

    response = await get('/bar');
    expect(response.headers['content-type'], contains('text/html'));
  });

  test('the default serializer sends what json.encode gives', () async {
    var response = await get('/payload');
    expect(response.statusCode, 200);
    expect(response.bodyBytes, utf8.encode(json.encode(_payload)));
    expect(response.headers['content-type'], contains('application/json'));
  });

  test('the default serializer calls toJson', () async {
    var response = await get('/to-json');
    expect(response.body, '[{"x":1,"y":2}]');
  });

  test('a buffered response is serialized into its buffer', () async {
    var response = await get('/buffered');
    expect(response.bodyBytes, utf8.encode(json.encode(_payload)));
    expect(response.headers['content-length'], '${response.bodyBytes.length}');
  });

  test('a custom serializer is still used', () async {
    var response = await get('/custom');
    expect(response.body, 'custom:{"a":1}');
  });

  test('code after an unawaited json() runs before the body is sent', () async {
    var response = await get('/unawaited');
    expect(response.statusCode, 201);
    expect(response.body, '{"created":true}');
  });

  test('a value that cannot be encoded is a 500', () async {
    var response = await get('/unencodable');
    expect(response.statusCode, 500);
  });
}
