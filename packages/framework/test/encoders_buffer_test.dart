import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data' show BytesBuilder;

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

Future<List<int>> getBody(MockHttpResponse rs) async {
  var list = await rs.toList();
  var bb = BytesBuilder();
  list.forEach(bb.add);
  return bb.takeBytes();
}

void main() {
  late Angel app;

  setUp(() {
    app = Angel(reflector: MirrorsReflector());
    app.encoders.addAll(
      {
        'deflate': zlib.encoder,
        'gzip': gzip.encoder,
      },
    );

    app.get('/hello', (req, res) {
      res
        ..useBuffer()
        ..write('Hello, world!');
    });
  });

  tearDown(() => app.close());

  encodingTests(() => app);
}

void encodingTests(Angel Function() getApp) {
  group('encoding', () {
    Angel app;
    late AngelHttp http;

    setUp(() {
      app = getApp();
      http = AngelHttp(app);
    });

    test('sends plaintext if no accept-encoding', () async {
      var rq = MockHttpRequest('GET', Uri.parse('/hello'));
      await rq.close();
      var rs = rq.response;
      await http.handleRequest(rq);

      var body = await rs.transform(utf8.decoder).join();
      expect(body, 'Hello, world!');
    });

    test('encodes if wildcard', () async {
      var rq = MockHttpRequest('GET', Uri.parse('/hello'))
        ..headers.set('accept-encoding', '*');
      await rq.close();
      var rs = rq.response;
      await http.handleRequest(rq);

      var body = await getBody(rs);
      //print(rs.headers);
      expect(rs.headers.value('content-encoding'), 'deflate');
      expect(body, zlib.encode(utf8.encode('Hello, world!')));
    });

    test('encodes if wildcard + multiple', () async {
      var rq = MockHttpRequest('GET', Uri.parse('/hello'))
        ..headers.set('accept-encoding', ['foo', 'bar', '*']);
      await rq.close();
      var rs = rq.response;
      await http.handleRequest(rq);

      var body = await getBody(rs);
      expect(rs.headers.value('content-encoding'), 'deflate');
      expect(body, zlib.encode(utf8.encode('Hello, world!')));
    });

    test('encodes if explicit', () async {
      var rq = MockHttpRequest('GET', Uri.parse('/hello'))
        ..headers.set('accept-encoding', 'gzip');
      await rq.close();
      var rs = rq.response;
      await http.handleRequest(rq);

      var body = await getBody(rs);
      expect(rs.headers.value('content-encoding'), 'gzip');
      expect(body, gzip.encode(utf8.encode('Hello, world!')));
    });

    test('only uses one encoder', () async {
      var rq = MockHttpRequest('GET', Uri.parse('/hello'));
      rq.headers.set('accept-encoding', ['gzip', 'deflate']);
      await rq.close();
      var rs = rq.response;
      await http.handleRequest(rq);

      var body = await getBody(rs);
      expect(rs.headers.value('content-encoding'), 'gzip');
      expect(body, gzip.encode(utf8.encode('Hello, world!')));
    });
  });
}
