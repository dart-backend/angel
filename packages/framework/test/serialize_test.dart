import 'dart:io';

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:test/test.dart';

void main() {
  late Angel app;
  late http.Client client;
  late HttpServer server;
  late String url;

  setUp(() async {
    app = Angel(reflector: MirrorsReflector())
      ..get('/foo', ioc(() => {'hello': 'world'}))
      ..get('/bar', (req, res) async {
        await res.serialize({'hello': 'world'},
            contentType: MediaType('text', 'html'));
      });
    client = http.Client();

    server = await AngelHttp(app).startServer();
    url = "http://${server.address.host}:${server.port}";
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test("correct content-type", () async {
    var response = await client.get(Uri.parse('$url/foo'));
    print('Response: ${response.body}');
    expect(response.headers['content-type'], contains('application/json'));

    response = await client.get(Uri.parse('$url/bar'));
    print('Response: ${response.body}');
    expect(response.headers['content-type'], contains('text/html'));
  });
}
