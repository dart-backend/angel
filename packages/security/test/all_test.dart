import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_security/angel3_security.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:test/test.dart';

void main() {
  group('CookieSigner', () {
    var signer = CookieSigner.fromStringKey('secret');

    test('verifies a value that contains dots', () {
      var signed = signer.createSignedCookie(Cookie('v', 'v1.abc'));
      expect(signer.verify(signed), isTrue);
      expect(signer.getCookiePayloadAndSignature(signed.value)![0], 'v1.abc');
    });

    test('refuses a tampered value or signature', () {
      var signed = signer.createSignedCookie(Cookie('role', 'user'));
      var sig = signer.getCookiePayloadAndSignature(signed.value)![1];
      expect(signer.verify(Cookie('role', 'admin.$sig')), isFalse);
      expect(signer.verify(Cookie('role', 'user.${sig}x')), isFalse);
      expect(signer.verify(Cookie('role', 'user')), isFalse);
    });

    test('keeps the attributes of the cookie, including SameSite', () {
      var cookie = Cookie('sid', 'x')
        ..httpOnly = true
        ..secure = true
        ..path = '/app'
        ..sameSite = SameSite.strict;
      var signed = signer.createSignedCookie(cookie);
      expect(signed.sameSite, SameSite.strict);
      expect(signed.httpOnly, isTrue);
      expect(signed.secure, isTrue);
      expect(signed.path, '/app');
    });
  });

  group('RateLimiter', () {
    late TestClient client;

    Future<TestClient> serve(RateLimiter<String> limiter) {
      var app = Angel()
        ..fallback(limiter.handleRequest)
        ..get('/', (req, res) => 'ok');
      return connectTo(app);
    }

    tearDown(() => client.close());

    test('rejects past the limit, with a Retry-After of at least 1', () async {
      client = await serve(
        InMemoryRateLimiter(2, const Duration(hours: 1), (req, res) => 'me'),
      );
      expect(await client.get(Uri.parse('/')), hasStatus(200));
      expect(await client.get(Uri.parse('/')), hasStatus(200));
      var rejected = await client.get(Uri.parse('/'));
      expect(rejected, hasStatus(429));
      expect(int.parse(rejected.headers['retry-after']!), greaterThan(0));
    });

    test('returns what rejectRequest returns', () async {
      client = await serve(
        _SoftLimiter(1, const Duration(hours: 1), (req, res) => 'me'),
      );
      expect(await client.get(Uri.parse('/')), hasStatus(200));
      var soft = await client.get(Uri.parse('/'));
      expect(soft.headers['x-soft-limit'], 'yes');
      // The request went on to the route.
      expect(soft.body, '"ok"');
    });

    test('InMemoryRateLimiter prunes after the clock is set back', () async {
      var limiter = InMemoryRateLimiter<String>(
        1,
        const Duration(minutes: 1),
        (req, res) => req.queryParameters['user'] as String,
      );
      var t0 = DateTime.utc(2026);
      var times = {
        't0': t0,
        't30m': t0.add(const Duration(minutes: 30)),
        't2h': t0.add(const Duration(hours: 2)),
      };
      var app = Angel()
        ..get('/', (req, res) async {
          var at = times[req.queryParameters['at']]!;
          var window = await limiter.getCurrentWindow(req, res, at);
          return window.startTime.toIso8601String();
        });
      client = await connectTo(app);

      Future<String> windowStart(String user, String at) async =>
          (await client.get(Uri.parse('/?user=$user&at=$at'))).body;

      await windowStart('x', 't2h');
      await windowStart('y', 't2h');
      // The clock is set back two hours: the windows made before, which
      // would last until it catches up, are removed.
      await windowStart('a', 't0');
      expect(await windowStart('y', 't0'), contains('T00:00'));
      // Half an hour later, `a`'s window has ended and is removed.
      await windowStart('b', 't30m');
      expect(await windowStart('a', 't30m'), contains('T00:30'));
    });

    test('InMemoryRateLimiter forgets ended windows', () async {
      var limiter = InMemoryRateLimiter<String>(
        1,
        const Duration(minutes: 1),
        (req, res) => req.queryParameters['user'] as String,
      );
      var start = DateTime.utc(2026);
      var later = start.add(const Duration(hours: 1));
      var app = Angel()
        ..get('/', (req, res) async {
          var at = req.queryParameters['at'] == 'later' ? later : start;
          var window = await limiter.getCurrentWindow(req, res, at);
          return window.startTime.toIso8601String();
        });
      client = await connectTo(app);

      Future<String> windowStart(String user, String at) async =>
          (await client.get(Uri.parse('/?user=$user&at=$at'))).body;

      expect(await windowStart('a', 'start'), contains('2026-01-01'));
      // Another user, later, makes the limiter remove the ended windows,
      // so `a` starts a new one.
      await windowStart('b', 'later');
      expect(await windowStart('a', 'later'), contains('T01:00'));
    });
  });
}

/// Lets requests past the limit through, marked with a header.
class _SoftLimiter extends InMemoryRateLimiter<String> {
  _SoftLimiter(super.maxPointsPerWindow, super.windowDuration, super.getUser);

  @override
  Object rejectRequest(
    RequestContext req,
    ResponseContext res,
    RateLimitingWindow<String> window,
    DateTime currentTime,
  ) {
    res.headers['x-soft-limit'] = 'yes';
    return true;
  }
}
