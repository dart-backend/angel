import 'dart:convert';
import 'dart:io';

import 'package:angel3_cache/angel3_cache.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:test/test.dart';

/// A server with a [ResponseCache] in front of handlers that count calls.
class _Harness {
  final Angel app = Angel();
  final Map<String, int> calls = {};
  late final ResponseCache cache;
  late final AngelHttp http;
  final HttpClient client = HttpClient();

  _Harness({int maxEntries = 1024, Duration? timeout}) {
    cache = ResponseCache(
      maxEntries: maxEntries,
      timeout: timeout ?? const Duration(minutes: 10),
    )..patterns.add(RegExp(r'^/'));
    app.fallback(cache.handleRequest);
    app.responseFinalizers.add(cache.responseFinalizer);
  }

  int count(String name) => calls.update(name, (v) => v + 1, ifAbsent: () => 1);

  /// Registers a buffered GET handler that returns `name:<call number>`.
  void buffered(String path, [void Function(ResponseContext res)? before]) {
    app.get(path, (req, res) {
      var n = count(path);
      res.useBuffer();
      before?.call(res);
      res.write('$path:$n');
    });
  }

  Future<void> start() => http.startServer('127.0.0.1', 0).then((_) {});

  Future<(int, String, HttpHeaders)> get(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    var uri = Uri.parse('${http.uri}$path');
    var rq = await client.getUrl(uri);
    headers.forEach(rq.headers.set);
    var rs = await rq.close();
    return (rs.statusCode, await rs.transform(utf8.decoder).join(), rs.headers);
  }

  Future<void> close() async {
    client.close(force: true);
    await http.close();
  }
}

void main() {
  late _Harness h;

  Future<void> setUpHarness({int maxEntries = 1024, Duration? timeout}) async {
    h = _Harness(maxEntries: maxEntries, timeout: timeout);
    h.http = AngelHttp(h.app);
  }

  tearDown(() => h.close());

  test('caches a buffered 200 response', () async {
    await setUpHarness();
    h.buffered('/page');
    await h.start();

    var (s1, b1, _) = await h.get('/page');
    var (s2, b2, headers) = await h.get('/page');
    expect((s1, s2), (200, 200));
    expect(b2, b1);
    expect(h.calls['/page'], 1);
    expect(headers.value('cache-control'), startsWith('public'));
  });

  test('does not cache an error, nor mark it cacheable', () async {
    await setUpHarness();
    var fail = true;
    h.app.get('/flaky', (req, res) {
      res.useBuffer();
      if (fail) {
        fail = false;
        throw StateError('temporary');
      }
      res.write('ok');
    });
    await h.start();

    var (s1, _, headers1) = await h.get('/flaky');
    expect(s1, 500);
    expect(headers1.value('cache-control'), isNot(contains('public')));

    var (s2, b2, _) = await h.get('/flaky');
    expect(s2, 200);
    expect(b2, 'ok');
  });

  test('does not cache other non-200 responses', () async {
    await setUpHarness();
    h.buffered('/created', (res) => res.statusCode = 201);
    await h.start();
    await h.get('/created');
    await h.get('/created');
    expect(h.calls['/created'], 2);
  });

  for (var directive in ['no-store', 'private', 'private, max-age=60']) {
    test('respects Cache-Control: $directive', () async {
      await setUpHarness();
      h.buffered('/secret', (res) => res.headers['cache-control'] = directive);
      await h.start();

      var (_, _, headers) = await h.get('/secret');
      await h.get('/secret');
      expect(h.calls['/secret'], 2);
      expect(headers.value('cache-control'), directive);
    });
  }

  test('does not cache responses that set cookies', () async {
    await setUpHarness();
    h.buffered('/session', (res) => res.cookies.add(Cookie('sid', 'abc')));
    await h.start();
    await h.get('/session');
    await h.get('/session');
    expect(h.calls['/session'], 2);
  });

  test('requests with Authorization bypass the cache', () async {
    await setUpHarness();
    h.buffered('/me');
    await h.start();
    var auth = {'authorization': 'Bearer token'};

    // An authenticated response is not stored...
    await h.get('/me', headers: auth);
    await h.get('/me');
    expect(h.calls['/me'], 2);

    // ...and a cached public response is not served to an authenticated one.
    await h.get('/me');
    expect(h.calls['/me'], 2);
    await h.get('/me', headers: auth);
    expect(h.calls['/me'], 3);
  });

  group('maxEntries', () {
    test('evicts the least recently used entry', () async {
      await setUpHarness(maxEntries: 2);
      h.buffered('/a');
      await h.start();

      await h.get('/a?1');
      await h.get('/a?2');
      await h.get('/a?1'); // hit: /a?1 is now the most recently used
      await h.get('/a?3'); // evicts /a?2
      expect(h.calls['/a'], 3);

      await h.get('/a?1');
      await h.get('/a?3');
      expect(h.calls['/a'], 3, reason: '/a?1 and /a?3 are cached');
      await h.get('/a?2');
      expect(h.calls['/a'], 4, reason: '/a?2 was evicted');
    });

    test('0 disables storing', () async {
      await setUpHarness(maxEntries: 0);
      h.buffered('/a');
      await h.start();
      await h.get('/a');
      await h.get('/a');
      expect(h.calls['/a'], 2);
    });
  });

  test('replaces an expired entry', () async {
    await setUpHarness(timeout: const Duration(milliseconds: 100));
    h.buffered('/page');
    await h.start();

    var (_, b1, _) = await h.get('/page');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    var (_, b2, _) = await h.get('/page');
    var (_, b3, _) = await h.get('/page');
    expect(b2, isNot(b1));
    expect(b3, b2);
    expect(h.calls['/page'], 2);
  });
}
