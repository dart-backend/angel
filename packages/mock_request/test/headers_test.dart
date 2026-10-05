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
  });
}
