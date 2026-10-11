import 'dart:io';

import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  group('date headers', () {
    test('are null when absent, as in dart:io', () {
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers;
      expect(headers.date, isNull);
      expect(headers.expires, isNull);
      expect(headers.ifModifiedSince, isNull);
    });

    test('are parsed when present', () {
      var time = DateTime.utc(2026, 1, 2, 3, 4, 5);
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..set(HttpHeaders.dateHeader, HttpDate.format(time))
        ..set(HttpHeaders.expiresHeader, HttpDate.format(time))
        ..set(HttpHeaders.ifModifiedSinceHeader, HttpDate.format(time));
      expect(headers.date, time);
      expect(headers.expires, time);
      expect(headers.ifModifiedSince, time);
    });

    test('round-trip through the setters', () {
      var time = DateTime.utc(2026, 1, 2, 3, 4, 5);
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..ifModifiedSince = time;
      expect(headers.ifModifiedSince, time);
    });

    test('setting null removes the header, as in dart:io', () {
      var time = DateTime.utc(2026, 1, 2, 3, 4, 5);
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..date = time
        ..expires = time
        ..ifModifiedSince = time;
      headers
        ..date = null
        ..expires = null
        ..ifModifiedSince = null;
      expect(headers.date, isNull);
      expect(headers.expires, isNull);
      expect(headers.ifModifiedSince, isNull);
    });
  });

  group('contentLength', () {
    test('is -1 when absent, as in dart:io', () {
      expect(MockHttpRequest('GET', Uri.parse('/')).headers.contentLength, -1);
    });

    test('is backed by the content-length header', () {
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..set(HttpHeaders.contentLengthHeader, '5');
      expect(headers.contentLength, 5);
      headers.contentLength = 7;
      expect(headers.value(HttpHeaders.contentLengthHeader), '7');
      headers.contentLength = -1;
      expect(headers.value(HttpHeaders.contentLengthHeader), isNull);
    });

    test('holds one value; a later one replaces it', () {
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..add(HttpHeaders.contentLengthHeader, '5')
        ..add(HttpHeaders.contentLengthHeader, 7);
      expect(headers[HttpHeaders.contentLengthHeader], ['7']);
      expect(headers.contentLength, 7);
    });

    test('rejects values that are not digits, as in dart:io', () {
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers;
      for (var bad in ['', '-3', '5,5', 'abc', -3, null, 1.5]) {
        expect(
          () => headers.set(HttpHeaders.contentLengthHeader, [bad]),
          throwsA(isA<HttpException>()),
          reason: '$bad',
        );
      }
    });

    test('rejects 16 or more significant digits, as in dart:io', () {
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..set(HttpHeaders.contentLengthHeader, '000999999999999999');
      expect(headers.contentLength, 999999999999999);
      expect(
        () => headers.set(HttpHeaders.contentLengthHeader, '1000000000000000'),
        throwsA(
          isA<HttpException>().having(
            (e) => e.message,
            'message',
            'Content-Length too large',
          ),
        ),
      );
    });

    test('a bad value changes nothing', () {
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..contentLength = 5;
      expect(
        () => headers.set(HttpHeaders.contentLengthHeader, ['10', 'x']),
        throwsA(isA<HttpException>()),
      );
      expect(headers.contentLength, 5);
    });

    test('takes any non-negative int, as in dart:io', () {
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..contentLength = 1 << 60;
      expect(headers.contentLength, 1 << 60);
    });

    test('set with no values removes it', () {
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..contentLength = 5
        ..set(HttpHeaders.contentLengthHeader, <String>[]);
      expect(headers.contentLength, -1);
    });

    test('cannot be set once the headers are locked', () {
      var rs = MockHttpRequest('GET', Uri.parse('/')).response..add([1]);
      expect(() => rs.contentLength = 1, throwsStateError);
    });
  });

  group('contentType', () {
    test('is null when absent, as in dart:io', () {
      expect(
        MockHttpRequest('GET', Uri.parse('/')).headers.contentType,
        isNull,
      );
    });

    test('setting null removes the header', () {
      var headers = MockHttpRequest('GET', Uri.parse('/')).headers
        ..contentType = ContentType.json;
      expect(headers.contentType?.mimeType, 'application/json');
      headers.contentType = null;
      expect(headers.value(HttpHeaders.contentTypeHeader), isNull);
    });
  });

  test('removing the last value removes the header, as in dart:io', () {
    var headers = MockHttpRequest('GET', Uri.parse('/')).headers
      ..set('x-foo', 'a')
      ..remove('x-foo', 'a');
    expect(headers.value('x-foo'), isNull);
    expect(headers['x-foo'], isNull);
  });

  group('chunkedTransferEncoding', () {
    MockHttpHeaders headers() =>
        MockHttpRequest('GET', Uri.parse('/')).headers as MockHttpHeaders;

    test('turning it on removes content-length, as in dart:io', () {
      var h = headers()
        ..contentLength = 5
        ..chunkedTransferEncoding = true;
      expect(h.contentLength, -1);
      expect(h.value(HttpHeaders.transferEncodingHeader), 'chunked');
    });

    test('setting a content-length turns it off', () {
      var h = headers()
        ..chunkedTransferEncoding = true
        ..contentLength = 5;
      expect(h.chunkedTransferEncoding, isFalse);
      expect(h.value(HttpHeaders.transferEncodingHeader), isNull);
    });

    test('follows the transfer-encoding header', () {
      var h = headers()
        ..contentLength = 5
        ..set(HttpHeaders.transferEncodingHeader, 'chunked');
      expect(h.chunkedTransferEncoding, isTrue);
      expect(h.contentLength, -1);
    });

    test('turning it off removes every chunked value', () {
      var h = headers()
        ..add('transfer-encoding', ['chunked', 'chunked'])
        ..chunkedTransferEncoding = false;
      expect(h.chunkedTransferEncoding, isFalse);
      expect(h.value(HttpHeaders.transferEncodingHeader), isNull);
    });

    test('cannot be changed once the headers are locked', () {
      var rq = MockHttpRequest('POST', Uri(path: '/'))..add([1]);
      expect(() => rq.headers.chunkedTransferEncoding = true, throwsStateError);
    });
  });

  test('connection settings cannot change once locked, as in dart:io', () {
    var headers = (MockHttpRequest('POST', Uri(path: '/'))..add([1])).headers;
    expect(() => headers.persistentConnection = false, throwsStateError);
    expect(() => headers.host = 'example.com', throwsStateError);
    expect(() => headers.port = 8080, throwsStateError);
  });

  test('preserveHeaderCase still stores the name lowercase, as in dart:io', () {
    var headers = MockHttpRequest('GET', Uri.parse('/')).headers
      ..set('x-a', '1')
      ..set('X-A', '2', preserveHeaderCase: true)
      ..set(
        'Content-Type',
        'text/plain; charset=latin1',
        preserveHeaderCase: true,
      );
    expect(headers['x-a'], ['2']);
    expect(headers.contentType?.charset, 'latin1');
    var names = <String>[];
    headers.forEach((name, _) => names.add(name));
    expect(names, ['x-a', 'content-type']);
  });

  test('a content-length removes every chunked value', () {
    var headers = MockHttpRequest('GET', Uri.parse('/')).headers
      ..add('transfer-encoding', ['chunked', 'chunked'])
      ..contentLength = 5;
    expect(headers.chunkedTransferEncoding, isFalse);
    expect(headers.contentLength, 5);
  });
}
