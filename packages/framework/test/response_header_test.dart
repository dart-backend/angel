import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/src/http/angel_http.dart';
import 'package:test/test.dart';

void main() {
  late Angel app;
  late AngelHttp http;
  late HttpClient client;

  setUp(() async {
    app = Angel();
    http = AngelHttp(app);

    await http.startServer();

    var formData = {'id': 100, 'name': 'William'};
    app.get('/api/v1/user/list', (RequestContext req, res) async {
      res.json(formData);
    });

    client = HttpClient();
  });

  tearDown(() async {
    client.close();
    await http.close();
  });

  Future<HttpHeaders> headers() async {
    var request = await client.getUrl(
      http.uri.replace(path: '/api/v1/user/list'),
    );
    var response = await request.close();
    await response.drain<void>();
    return response.headers;
  }

  group('removeResponseHeader', () {
    test('removes each value of a list', () async {
      http.addResponseHeader({
        'x-list': ['a', 'b', 'c'],
      });
      http.removeResponseHeader({
        'x-list': ['a', 'c'],
      });
      expect((await headers())['x-list'], ['b']);
    });

    test('removes one value of a header with several', () async {
      http.addResponseHeader({
        'x-list': ['a', 'b'],
      });
      http.removeResponseHeader({'x-list': 'a'});
      expect((await headers())['x-list'], ['b']);
    });

    test('skips a null in a list', () async {
      http.addResponseHeader({
        'x-list': ['a', 'b'],
      });
      http.removeResponseHeader({
        'x-list': <String?>['a', null],
      });
      expect((await headers())['x-list'], ['b']);
    });

    test('removes every equal value', () async {
      http.addResponseHeader({
        'x-list': ['a', 'a', 'b'],
      });
      http.removeResponseHeader({
        'x-list': ['a'],
      });
      expect((await headers())['x-list'], ['b']);
    });

    test('matches ignoring case when nothing matches exactly', () async {
      http.removeResponseHeader({'x-frame-options': 'sameorigin'});
      expect((await headers())['x-frame-options'], isNull);
    });

    test('keeps a value that differs in case from an exact match', () async {
      http.addResponseHeader({
        'x-token': ['AbC', 'abc'],
      });
      http.removeResponseHeader({'x-token': 'abc'});
      expect((await headers())['x-token'], ['AbC']);
    });

    test('matches a DateTime as dart:io stores it', () async {
      var date = DateTime.utc(2026, 10, 25);
      http.addResponseHeader({'x-date': date});
      http.removeResponseHeader({'x-date': date});
      expect((await headers())['x-date'], isNull);
    });

    test('with null removes a header whatever its values', () async {
      http.removeResponseHeader({'x-xss-protection': null});
      expect((await headers())['x-xss-protection'], isNull);
    });

    test('matches a value that is not a string by its text', () async {
      http.addResponseHeader({'x-number': 5});
      http.removeResponseHeader({'x-number': 5});
      expect((await headers())['x-number'], isNull);
    });

    test('keeps a header without the value', () async {
      http.addResponseHeader({'x-list': 'a'});
      http.removeResponseHeader({'x-list': 'z'});
      expect((await headers())['x-list'], ['a']);
    });
  });

  test('addResponseHeader adds none of headers with one it cannot', () async {
    expect(
      () => http.addResponseHeader({'x-a': '1', 'content-type': 5}),
      throwsArgumentError,
    );
    expect((await headers())['x-a'], isNull);
  });

  test('addResponseHeader skips a null in a list', () async {
    http.addResponseHeader({
      'x-list': <String?>['a', null],
    });
    expect((await headers())['x-list'], ['a']);
  });

  test('Add Response Header', () async {
    http.addResponseHeader({
      'X-XSRF_TOKEN':
          'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
    });
    expect(
      (await headers())['X-XSRF_TOKEN'],
      equals([
        'a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e',
      ]),
    );
  });
}
