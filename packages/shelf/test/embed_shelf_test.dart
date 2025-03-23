import 'dart:convert';
import 'dart:io';
import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_shelf/angel3_shelf.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:charcode/charcode.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  late http.Client client;
  late HttpServer server;

  Uri path(String p) {
    return Uri(
        scheme: 'http',
        host: server.address.address,
        port: server.port,
        path: p);
  }

  setUp(() async {
    client = http.Client();
    var handler = shelf.Pipeline().addHandler((shelf.Request request) {
      if (request.url.path == 'two') {
        return shelf.Response(200, body: json.encode(2));
      } else if (request.url.path == 'error') {
        throw AngelHttpException.notFound();
      } else if (request.url.path == 'status') {
        return shelf.Response.notModified(headers: {'foo': 'bar'});
      } else if (request.url.path == 'hijack') {
        request.hijack((StreamChannel<List<int>> channel) {
          print('a');
          var sink = channel.sink;
          sink.add(utf8.encode('HTTP/1.1 200 OK\r\n'));
          sink.add([$lf]);
          sink.add(utf8.encode(json.encode({'error': 'crime'})));
          sink.close();
          print('b');
        });
        //} else if (request.url.path == 'throw') {
        //  return null;
      } else {
        return shelf.Response.ok('Request for "${request.url}"');
      }
    });

    var logger = Logger.detached('angel3_shelf')..onRecord.listen(prettyLog);
    var app = Angel(logger: logger, reflector: MirrorsReflector());
    var httpDriver = AngelHttp(app);
    app.get('/angel', (req, res) => 'Angel');
    app.fallback(embedShelf(handler, throwOnNullResponse: true));

    server = await httpDriver.startServer(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('expose angel side', () async {
    var response = await client.get(path('/angel'));
    expect(json.decode(response.body), equals('Angel'));
  });

  test('expose shelf side', () async {
    var response = await client.get(path('/foo'));
    expect(response, hasStatus(200));
    expect(response.body, equals('Request for "foo"'));
  });

  test('shelf can return arbitrary values', () async {
    var response = await client.get(path('/two'));
    expect(response, isJson(2));
  });

  test('shelf can hijack', () async {
    try {
      var client = HttpClient();
      var rq = await client.openUrl('GET', path('/hijack'));
      var rs = await rq.close();
      var body = await rs.cast<List<int>>().transform(utf8.decoder).join();
      print('Response: $body');
      expect(json.decode(body), {'error': 'crime'});
    } on HttpException catch (e, st) {
      print('HTTP Exception: ${e.message}');
      print(st);
      rethrow;
    }
  });

  test('shelf can set status code', () async {
    var response = await client.get(path('/status'));
    expect(response, allOf(hasStatus(304), hasHeader('foo', 'bar')));
  });

  test('shelf can throw error', () async {
    var response = await client.get(path('/error'));
    expect(response, hasStatus(404));
  });

  test('throw on null', () async {
    var response = await client.get(path('/throw'));
    expect(response, hasStatus(500));
  });
}
