import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
        'a-é☺!\n',
      );
    });

    test('contentLength counts each byte once', () async {
      var rq = MockHttpRequest('POST', Uri(path: '/'))
        ..add(utf8.encode('hello'))
        ..write('é');
      await rq.close();
      expect(rq.contentLength, 7);
      expect(rq.headers.contentLength, 7);
    });

    test('write(null) and writeln(null) write "null", as in dart:io', () async {
      var rq = MockHttpRequest('POST', Uri(path: '/'))
        ..write(null)
        ..writeln(null)
        ..writeln();
      await rq.close();
      expect(utf8.decode(await bytesOf(rq)), 'nullnull\n\n');
    });

    test('an empty write does not lock the headers', () {
      var rq = MockHttpRequest('POST', Uri(path: '/'))
        ..write('')
        ..writeAll(<String>[]);
      rq.headers.set('x-foo', 'bar');
      expect(rq.headers.value('x-foo'), 'bar');
    });

    test('close sets no content-length without a body', () async {
      var rq = MockHttpRequest('GET', Uri(path: '/'));
      await rq.close();
      expect(rq.contentLength, -1);
    });

    test('close sets no content-length with a chunked header', () async {
      var rq = MockHttpRequest('POST', Uri(path: '/'))
        ..headers.set('transfer-encoding', 'chunked')
        ..write('hello');
      await rq.close();
      expect(rq.contentLength, -1);
    });

    test('close sets no content-length with chunked encoding', () async {
      var rq = MockHttpRequest('POST', Uri(path: '/'))
        ..headers.chunkedTransferEncoding = true
        ..write('hello');
      await rq.close();
      expect(rq.contentLength, -1);
    });

    test('close keeps a content-length that was set', () async {
      var rq = MockHttpRequest('POST', Uri(path: '/'))
        ..headers.contentLength = 2
        ..write('hello');
      await rq.close();
      expect(rq.contentLength, 2);
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

    test('emits no empty chunks', () async {
      var empty = request();
      await empty.close();
      expect(await empty.isEmpty, isTrue);

      var flushed = request()..add([1]);
      await flushed.flush();
      await flushed.flush();
      await flushed.close();
      expect(await flushed.single, [1]);
    });

    test('firstWhere without orElse throws StateError on no match', () async {
      var rq = request()..add([1]);
      await rq.close();
      expect(rq.firstWhere((_) => false), throwsStateError);
    });

    test('addError comes after the bytes added before it', () async {
      var rq = request()..add([1]);
      rq.addError(StateError('boom'));
      await rq.close();
      var events = <Object>[];
      var done = Completer<void>();
      rq.listen(events.add, onError: events.add, onDone: done.complete);
      await done.future;
      expect(events, [
        [1],
        isStateError,
      ]);
    });

    test('a stream that finishes during listen does not stay bound', () async {
      var rq = request();
      await rq.addStream(_DoneDuringListen());
      rq.add([1]);
      await rq.close();
      expect(await bytesOf(rq), [1]);
    });

    test('a stream that cannot be listened to does not bind', () async {
      var rq = request();
      var source = StreamController<List<int>>();
      source.stream.listen((_) {});
      expect(() => rq.addStream(source.stream), throwsStateError);
      rq.add([1]);
      await rq.close();
      expect(await bytesOf(rq), [1]);
    });
  });

  group('MockHttpResponse', () {
    MockHttpResponse response({int statusCode = 200, Encoding? encoding}) =>
        MockHttpResponse(
          statusCode: statusCode,
          reasonPhrase: '',
          encoding: encoding ?? utf8,
          persistentConnection: false,
        );

    test('has no content-length unless one is given', () {
      expect(response().contentLength, -1);
      expect(response().headers.value('content-length'), isNull);
    });

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

    test('write uses the content-type charset over its encoding', () async {
      var rs = response();
      rs.headers.contentType = ContentType('text', 'plain', charset: 'latin1');
      rs.write('é');
      await rs.close();
      expect(rs.encoding, latin1);
      expect(await bytesOf(rs), [0xE9]);
    });

    test(
      'write keeps the encoding of the first write, as in dart:io',
      () async {
        var rs = response(encoding: latin1)..write('é');
        rs.encoding = utf8;
        expect(rs.encoding, latin1); // What the writes use.
        rs.write('é');
        await rs.close();
        expect(await bytesOf(rs), [0xE9, 0xE9]);
      },
    );

    test('a failed first write does not keep its encoding', () async {
      var rs = response()
        ..headers.contentType = ContentType('text', 'plain', charset: 'latin1');
      expect(() => rs.write('☺'), throwsArgumentError);
      rs.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
      rs.write('☺');
      await rs.close();
      expect(utf8.decode(await bytesOf(rs)), '☺');
    });

    test('encoding follows changes to the content-type header', () {
      var rs = response()
        ..headers.contentType = ContentType('text', 'plain', charset: 'latin1');
      expect(rs.encoding, latin1);
      rs.headers.contentType = ContentType('text', 'plain', charset: 'utf-8');
      expect(rs.encoding, utf8);
      rs.headers.contentType = null;
      expect(rs.encoding, utf8); // The constructor's.
    });

    test('write uses its encoding without a content-type charset', () async {
      var rs = response(encoding: latin1);
      rs.headers.set('content-type', 'text/plain');
      expect(rs.encoding, latin1);
      rs.headers.set('content-type', 'text/plain; charset=x-unknown');
      expect(rs.encoding, latin1);
    });

    test('a stream that finishes during listen does not stay bound', () async {
      var rs = response();
      await rs.addStream(_DoneDuringListen());
      rs.add([1]);
      await rs.close();
      expect(await bytesOf(rs), [1]);
    });

    test('an empty add does not lock the headers', () {
      var rs = response()..add(<int>[]);
      rs.headers.contentType = ContentType.json;
      expect(rs.headers.contentType?.mimeType, 'application/json');
    });

    test('without buffering, added bytes are copied', () async {
      var rs = response()..bufferOutput = false;
      var chunks = <List<int>>[];
      rs.listen(chunks.add);
      var bytes = Uint8List.fromList([1, 2, 3]);
      rs.add(bytes);
      bytes[0] = 9;
      await Future<void>.delayed(Duration.zero);
      expect(chunks, [
        [1, 2, 3],
      ]);
      await rs.close();
    });

    test('bufferOutput can be turned off before writing', () async {
      var rs = response()..bufferOutput = false;
      var chunks = <List<int>>[];
      rs.listen(chunks.add);
      rs.add([1]);
      await Future<void>.delayed(Duration.zero);
      expect(chunks, [
        [1],
      ]); // Before close.
      expect(() => rs.bufferOutput = true, throwsStateError);
      await rs.close();
    });

    test('write throws for a character its encoding cannot represent', () {
      expect(() => response(encoding: latin1).write('☺'), throwsArgumentError);
    });
  });
}

/// Calls onDone before listen returns, as a misbehaving stream might.
class _DoneDuringListen extends Stream<List<int>> {
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    onDone?.call();
    return const Stream<List<int>>.empty().listen(null);
  }
}
