import 'dart:io';

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  late Angel app;
  late http.Client client;
  late HttpServer server;
  late String url;

  setUp(() async {
    app = Angel(reflector: MirrorsReflector())
      ..post('/foo', (req, res) => res.serialize({'hello': 'world'}))
      ..all('*', (req, res) => throw AngelHttpException.notFound());
    client = http.Client();

    server = await AngelHttp(app).startServer();
    url = 'http://${server.address.host}:${server.port}';
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('allow override of method', () async {
    var response = await client.get(
      Uri.parse('$url/foo'),
      headers: {'X-HTTP-Method-Override': 'POST'},
    );
    print('Response: ${response.body}');
    expect(json.decode(response.body), equals({'hello': 'world'}));
  });

  test('unmatched route without fallback returns 404', () async {
    var app = Angel()..get('/foo', (req, res) => 'foo');
    var rq = MockHttpRequest('GET', Uri(path: '/bar'))
      ..headers.set('accept', 'application/json');
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    var rs = rq.response;
    var body = await rs.transform(utf8.decoder).join();
    expect(rs.statusCode, 404);
    expect(json.decode(body)['status_code'], 404);
  });
}
