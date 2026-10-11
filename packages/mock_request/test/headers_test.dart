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
      for (var bad in ['', '-3', '5,5', 'abc', '99999999999999999999']) {
        expect(
          () => headers.set(HttpHeaders.contentLengthHeader, bad),
          throwsA(isA<HttpException>()),
          reason: bad,
        );
      }
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
}
