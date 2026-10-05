import 'dart:async';
import 'dart:convert';

import 'package:angel3_cache/angel3_cache.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  late Angel app;
  late AngelHttp http;
  late int serialized;
  final shared = {'expensive': 'object'};

  void setUpApp({
    Duration? timeout,
    FutureOr<bool> Function(RequestContext, ResponseContext, Object)?
    shouldCache,
  }) {
    serialized = 0;
    app = Angel()
      ..serializer = (value) {
        serialized++;
        return json.encode(value);
      }
      ..fallback(
        cacheSerializationResults(timeout: timeout, shouldCache: shouldCache),
      )
      ..get('/shared', (req, res) => shared)
      ..get('/fresh', (req, res) => {'new': 'object'})
      ..get('/text', (req, res) => 'plain')
      ..get('/number', (req, res) => 42)
      ..get('/jsonp', (req, res) => res.jsonp(shared));
    http = AngelHttp(app);
  }

  Future<String> get(String path) async {
    var rq = MockHttpRequest('GET', Uri(path: path));
    await rq.close();
    await http.handleRequest(rq);
    return rq.response.transform(utf8.decoder).join();
  }

  test('serializes a shared object once across requests', () async {
    setUpApp();
    for (var i = 0; i < 3; i++) {
      expect(await get('/shared'), json.encode(shared));
    }
    expect(serialized, 1);
  });

  test('serializes distinct objects each time', () async {
    setUpApp();
    await get('/fresh');
    await get('/fresh');
    expect(serialized, 2);
  });

  test('does not cache strings or numbers, which still work', () async {
    setUpApp();
    expect(await get('/text'), json.encode('plain'));
    expect(await get('/text'), json.encode('plain'));
    expect(await get('/number'), '42');
    expect(serialized, 3);
  });

  test('consults shouldCache', () async {
    var asked = <Object>[];
    setUpApp(
      shouldCache: (req, res, value) {
        asked.add(value);
        return false;
      },
    );
    await get('/shared');
    await get('/shared');
    expect(asked, [shared, shared]);
    expect(serialized, 2);
  });

  test('supports an async shouldCache', () async {
    setUpApp(shouldCache: (req, res, value) async => req.path == 'shared');
    await get('/shared');
    await get('/shared');
    expect(serialized, 1);
  });

  test('expires results after timeout', () async {
    setUpApp(timeout: const Duration(milliseconds: 50));
    await get('/shared');
    await get('/shared');
    expect(serialized, 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await get('/shared');
    expect(serialized, 2);
  });

  test('keeps res.jsonp working', () async {
    setUpApp();
    expect(await get('/jsonp'), 'callback(${json.encode(shared)})');
    expect(await get('/jsonp'), 'callback(${json.encode(shared)})');
    expect(serialized, 1);
  });

  test('does not reuse a result produced by another serializer', () async {
    var jsonCalls = 0;
    var app = Angel()
      ..serializer = (value) {
        jsonCalls++;
        return json.encode(value);
      }
      // Runs before the cache middleware, so the cache wraps this serializer.
      ..fallback((req, res) {
        if (req.path == 'other') res.serializer = (value) => 'other';
        return true;
      })
      ..fallback(cacheSerializationResults())
      ..get('/shared', (req, res) => shared)
      ..get('/other', (req, res) => shared);
    var http = AngelHttp(app);

    Future<String> fetch(String path) async {
      var rq = MockHttpRequest('GET', Uri(path: path));
      await rq.close();
      await http.handleRequest(rq);
      return rq.response.transform(utf8.decoder).join();
    }

    expect(await fetch('/shared'), json.encode(shared));
    expect(await fetch('/other'), 'other');
    expect(await fetch('/shared'), json.encode(shared));
    expect(jsonCalls, 2);
  });
}
