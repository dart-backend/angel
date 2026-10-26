import 'dart:convert';
import 'dart:io';

import 'package:angel3_cache/angel3_cache.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:file/local.dart';
import 'package:test/test.dart';

/// A server with a [ResponseCache] in front of handlers that count calls.
class _Harness {
  final Angel app = Angel();
  final Map<String, int> calls = {};
  late final ResponseCache cache;
  late final AngelHttp http;
  final HttpClient client = HttpClient();

  _Harness({
    int maxEntries = 1024,
    Duration? timeout,
    int maxEntryBytes = 1024 * 1024,
    bool cacheRequestsWithCookies = false,
  }) {
    cache = ResponseCache(
      maxEntries: maxEntries,
      timeout: timeout ?? const Duration(minutes: 10),
      maxEntryBytes: maxEntryBytes,
      cacheRequestsWithCookies: cacheRequestsWithCookies,
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

  Future<void> setUpHarness({
    int maxEntries = 1024,
    Duration? timeout,
    int maxEntryBytes = 1024 * 1024,
    bool cacheRequestsWithCookies = false,
  }) async {
    h = _Harness(
      maxEntries: maxEntries,
      timeout: timeout,
      maxEntryBytes: maxEntryBytes,
      cacheRequestsWithCookies: cacheRequestsWithCookies,
    );
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

  group('without useBuffer()', () {
    test('caches a normal (unbuffered) response', () async {
      await setUpHarness();
      h.app.get('/plain', (req, res) => 'plain:${h.count('/plain')}');
      await h.start();

      var (_, b1, _) = await h.get('/plain');
      var (_, b2, _) = await h.get('/plain');
      expect(b2, b1);
      expect(h.calls['/plain'], 1);
    });

    test('caches a streamed file with its full body', () async {
      await setUpHarness();
      h.app.get('/file', (req, res) {
        h.count('/file');
        return res.streamFile(const LocalFileSystem().file('pubspec.yaml'));
      });
      await h.start();

      var file = File('pubspec.yaml').readAsStringSync();
      var (_, b1, _) = await h.get('/file');
      var (s2, b2, _) = await h.get('/file');
      expect(b1, file);
      expect((s2, b2), (200, file));
      expect(h.calls['/file'], 1);
    });
  });

  group('If-Modified-Since', () {
    late String lastModified;

    setUp(() async {
      await setUpHarness();
      h.buffered('/page');
      h.app.get('/uncached', (req, res) => 'u:${h.count('/uncached')}');
      h.cache.patterns
        ..clear()
        ..add(RegExp(r'^/page'));
      await h.start();
      var (_, _, headers) = await h.get('/page');
      lastModified = headers.value('last-modified')!;
    });

    test('the exact Last-Modified value gets a 304 without a body', () async {
      var (status, body, headers) = await h.get(
        '/page',
        headers: {'if-modified-since': lastModified},
      );
      expect(status, 304);
      expect(body, isEmpty);
      expect(headers.value('last-modified'), lastModified);
      expect(headers.value('cache-control'), startsWith('public'));
      expect(h.calls['/page'], 1);
    });

    test('a later date gets a 304', () async {
      var (status, _, _) = await h.get(
        '/page',
        headers: {
          'if-modified-since': HttpDate.format(
            DateTime.now().add(const Duration(days: 1)),
          ),
        },
      );
      expect(status, 304);
    });

    test('an earlier date gets the cached 200 response', () async {
      var (status, body, _) = await h.get(
        '/page',
        headers: {
          'if-modified-since': HttpDate.format(
            HttpDate.parse(lastModified).subtract(const Duration(days: 1)),
          ),
        },
      );
      expect(status, 200);
      expect(body, '/page:1');
      expect(h.calls['/page'], 1, reason: 'served from the cache');
    });

    test('is ignored for requests with Authorization', () async {
      var (status, body, _) = await h.get(
        '/page',
        headers: {'if-modified-since': lastModified, 'authorization': 'x'},
      );
      expect(status, 200);
      expect(body, '/page:2');
    });

    test('is ignored for paths that are not cached', () async {
      var (status, _, _) = await h.get(
        '/uncached',
        headers: {'if-modified-since': lastModified},
      );
      expect(status, 200);
    });
  });

  group('requests with cookies', () {
    test('bypass the cache', () async {
      await setUpHarness();
      h.buffered('/dashboard');
      await h.start();
      var session = {'cookie': 'sid=alice'};

      // A response to a session is not stored...
      await h.get('/dashboard', headers: session);
      await h.get('/dashboard');
      expect(h.calls['/dashboard'], 2);

      // ...and a cached public response is not served to a session.
      await h.get('/dashboard', headers: session);
      expect(h.calls['/dashboard'], 3);
    });

    test('use the cache with cacheRequestsWithCookies', () async {
      await setUpHarness(cacheRequestsWithCookies: true);
      h.buffered('/public');
      await h.start();
      await h.get('/public', headers: {'cookie': 'analytics=1'});
      await h.get('/public');
      expect(h.calls['/public'], 1);
    });
  });

  test('does not store a response varying by other headers', () async {
    await setUpHarness();
    h.buffered('/i18n', (res) => res.headers['vary'] = 'accept-language');
    h.buffered('/gzip', (res) => res.headers['vary'] = 'Accept-Encoding');
    await h.start();
    await h.get('/i18n');
    await h.get('/i18n');
    expect(h.calls['/i18n'], 2);
    await h.get('/gzip');
    await h.get('/gzip');
    expect(h.calls['/gzip'], 1);
  });

  test('a HEAD response is not served to GET', () async {
    await setUpHarness();
    h.buffered('/report');
    await h.start();
    var rq = await h.client.headUrl(Uri.parse('${h.http.uri}/report'));
    await (await rq.close()).drain<void>();

    var (status, body, _) = await h.get('/report');
    expect(status, 200);
    expect(body, startsWith('/report:'));
  });

  test('a response that is not stored is not marked cacheable', () async {
    await setUpHarness(maxEntries: 0);
    h.buffered('/never');
    await h.start();
    var (_, _, headers) = await h.get('/never');
    expect(headers.value('cache-control'), isNot(contains('public')));
    expect(headers.value('last-modified'), isNull);
  });

  test('does not store a response larger than maxEntryBytes', () async {
    await setUpHarness(maxEntryBytes: 4);
    h.buffered('/large');
    await h.start();
    var (_, body, headers) = await h.get('/large');
    expect(body, '/large:1');
    expect(headers.value('cache-control'), isNot(contains('public')));
    await h.get('/large');
    expect(h.calls['/large'], 2);
  });

  test('does not store a response the handler encoded', () async {
    await setUpHarness();
    h.buffered('/pre.br', (res) => res.headers['content-encoding'] = 'br');
    await h.start();
    await h.get('/pre.br');
    await h.get('/pre.br');
    expect(h.calls['/pre.br'], 2);
  });

  test('keeps the Cache-Control of the handler', () async {
    await setUpHarness();
    h.buffered('/short', (res) => res.headers['cache-control'] = 'max-age=30');
    h.buffered(
      '/revalidate',
      (res) => res.headers['cache-control'] = 'no-cache',
    );
    await h.start();

    var (_, _, first) = await h.get('/short');
    var (_, _, cached) = await h.get('/short');
    expect(h.calls['/short'], 1);
    expect(first.value('cache-control'), 'max-age=30');
    expect(cached.value('cache-control'), 'max-age=30');

    // `no-cache` is revalidated each time, so it is not stored.
    await h.get('/revalidate');
    await h.get('/revalidate');
    expect(h.calls['/revalidate'], 2);
  });
}
