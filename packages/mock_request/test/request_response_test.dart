import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

Future<List<int>> bytesOf(Stream<List<int>> stream) =>
    stream.fold<List<int>>([], (out, chunk) => out..addAll(chunk));

void main() {
  const text = 'héllo ☺ 👋';

  group('MockHttpRequest', () {
    test('write encodes text as UTF-8', () async {
      var rq = MockHttpRequest('POST', Uri(path: '/'))
        ..write(text)
        ..writeAll(['a', 'é'], '-')
        ..writeCharCode(0x263A)
        ..writeln('!');
      await rq.close();
      expect(
        utf8.decode(await bytesOf(rq)),
        '$text'
        'a-é☺!\r\n',
      );
    });

    test('contentLength counts each byte once', () async {
      var rq = MockHttpRequest('POST', Uri(path: '/'))
        ..add(utf8.encode('hello'))
        ..write('é');
      await rq.close();
      expect(rq.contentLength, 7);
    });

    test('write uses the content-type charset', () async {
      var rq = MockHttpRequest('POST', Uri(path: '/'));
      rq.headers.contentType = ContentType('text', 'plain', charset: 'latin1');
      rq.write('é');
      await rq.close();
      expect(await bytesOf(rq), [0xE9]);
    });

    test('write falls back to UTF-8 for an unknown charset', () async {
      var rq = MockHttpRequest('POST', Uri(path: '/'));
      rq.headers.set('content-type', 'text/plain; charset=x-unknown');
      rq.write('é');
      await rq.close();
      expect(await bytesOf(rq), utf8.encode('é'));
    });
  });

  group('MockHttpRequest as a sink', () {
    MockHttpRequest request() => MockHttpRequest('POST', Uri(path: '/'));

    test('close can be called twice', () async {
      var rq = request()..write('a');
      await rq.close();
      await rq.close();
      expect(await bytesOf(rq), utf8.encode('a'));
    });

    test('writes fail while addStream is running', () async {
      var rq = request();
      var source = StreamController<List<int>>();
      var added = rq.addStream(source.stream);
      expect(() => rq.add([1]), throwsStateError);
      expect(() => rq.addStream(Stream.empty()), throwsStateError);
      expect(rq.flush, throwsStateError);
      expect(rq.close, throwsStateError);
      source.add([1, 2]);
      await source.close();
      await added;
      await rq.close();
      expect(await bytesOf(rq), [1, 2]);
    });

    test('addStream completes with the source error', () async {
      var rq = request();
      await expectLater(
        rq.addStream(Stream.error(StateError('boom'))),
        throwsStateError,
      );
      rq.add([1]); // No longer bound.
    });
  });

  group('MockHttpResponse', () {
    MockHttpResponse response({int statusCode = 200, Encoding? encoding}) =>
        MockHttpResponse(
          statusCode: statusCode,
          reasonPhrase: '',
          contentLength: 0,
          encoding: encoding ?? utf8,
          persistentConnection: false,
        );

    test('keeps the statusCode it is given', () {
      expect(response(statusCode: 404).statusCode, 404);
    });

    test('write encodes text with its encoding', () async {
      var rs = response()
        ..write(text)
        ..writeCharCode(0x263A);
      await rs.close();
      expect(utf8.decode(await bytesOf(rs)), '$text☺');

      var latin = response(encoding: latin1)..write('é');
      await latin.close();
      expect(await bytesOf(latin), [0xE9]);
    });

    test('contentLength is headers.contentLength', () {
      var rs = response();
      rs.headers.contentLength = 5;
      expect(rs.contentLength, 5);
      rs.contentLength = 7;
      expect(rs.headers.contentLength, 7);
    });

    test('write throws for a character its encoding cannot represent', () {
      expect(() => response(encoding: latin1).write('☺'), throwsArgumentError);
    });
  });
}
