import 'dart:async';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart' hide Header;
import 'package:angel3_framework/http.dart';
import 'package:angel3_framework/http2.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:http2/transport.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

/// Request paths, and the path a request context gives for each: leading and
/// trailing slashes are removed, and a path of none but slashes is `/`.
const paths = {
  '/': '/',
  '//': '/',
  '/a': 'a',
  '/a/': 'a',
  '///a///': 'a',
  '/users//1//': 'users//1',
  '/a/b/c': 'a/b/c',
};

void main() {
  group('HTTP/1', () {
    var http = AngelHttp(Angel());
    for (var MapEntry(key: path, value: expected) in paths.entries) {
      test('"$path" gives "$expected"', () async {
        var rq = MockHttpRequest('GET', Uri(path: path));
        var req = await http.createRequestContext(rq, rq.response);
        expect(req.path, expected);
      });
    }
  });

  group('HTTP/2', () {
    for (var MapEntry(key: path, value: expected) in paths.entries) {
      test('"$path" gives "$expected"', () async {
        var stream = _FakeStream();
        var req = Http2RequestContext.from(
          stream,
          _FakeSocket(),
          Angel(),
          {},
          const Uuid(),
        );
        stream.messages.add(
          HeadersStreamMessage([
            Header.ascii(':method', 'GET'),
            Header.ascii(':path', path),
          ], endStream: true),
        );
        expect((await req).path, expected);
      });
    }
  });
}

class _FakeStream implements ServerTransportStream {
  final messages = StreamController<StreamMessage>();

  @override
  Stream<StreamMessage> get incomingMessages => messages.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocket implements Socket {
  @override
  InternetAddress get address => InternetAddress.loopbackIPv4;

  @override
  int get port => 443;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
