import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  late Angel app;
  late AngelHttp http;
  late int apiCreations;

  setUp(() {
    apiCreations = 0;
    var router = HostnameRouter(
      apps: {
        'admin.example.com:8443': Angel()..get('/', (req, res) => 'admin'),
        '*.shop.test': Angel()..get('/', (req, res) => 'wildcard'),
      },
      creators: {
        'api.example.com': () async {
          apiCreations++;
          // Yield, so concurrent first requests overlap during creation.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return Angel()
            ..get('/', (req, res) => 'api')
            ..get('/users/:id', (req, res) => 'user ${req.params['id']}');
        },
      },
    );

    app = Angel()
      ..fallback(router.handleRequest)
      ..fallback((req, res) => 'main');
    http = AngelHttp(app);
  });

  Future<String> get(String path, {required String host}) async {
    var rq = MockHttpRequest('GET', Uri(path: path))..headers.set('host', host);
    await rq.close();
    unawaited(http.handleRequest(rq));
    return json.decode(await rq.response.transform(utf8.decoder).join())
        as String;
  }

  test('routes by hostname', () async {
    expect(await get('/', host: 'api.example.com'), 'api');
  });

  test('falls through to the main app for unknown hosts', () async {
    expect(await get('/', host: 'other.test'), 'main');
  });

  test('matches case-insensitively', () async {
    expect(await get('/', host: 'API.Example.com'), 'api');
  });

  test('passes route params to the sub-app', () async {
    expect(await get('/users/7', host: 'api.example.com'), 'user 7');
  });

  group('ports', () {
    test('a pattern without a port matches a host with one', () async {
      expect(await get('/', host: 'api.example.com:8080'), 'api');
    });

    test('wildcards match a host with a port', () async {
      expect(await get('/', host: 'a.shop.test:3000'), 'wildcard');
    });

    test('a pattern with a port still matches exactly', () async {
      expect(await get('/', host: 'admin.example.com:8443'), 'admin');
    });

    test('a pattern with a port does not match another port', () async {
      // The bare hostname matches no pattern either, so the main app answers.
      expect(await get('/', host: 'admin.example.com:9999'), 'main');
    });
  });

  test('creates each app once under concurrent first requests', () async {
    var results = await Future.wait([
      for (var i = 0; i < 5; i++) get('/', host: 'api.example.com'),
    ]);
    expect(results, everyElement('api'));
    expect(apiCreations, 1);
  });
}
