import 'dart:convert';
import 'dart:io';

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// The users of the tests, by id.
final users = <String, String>{'alice': 'Alice', 'bob': 'Bob'};

/// A response to a test request.
typedef Got = ({int status, Object? body, List<Cookie> cookies});

class Site {
  final Angel app = Angel();
  late final AngelHttp http = AngelHttp(app);
  late final AngelAuth<String?> auth;

  Site({
    num? jwtLifeSpan,
    bool allowTokenInQuery = false,
    Duration reviveGracePeriod = Duration.zero,
    String? jwtKey = 'key',
  }) {
    auth = AngelAuth<String?>(
      jwtKey: jwtKey,
      serializer: (user) =>
          users.entries.firstWhere((e) => e.value == user).key,
      deserializer: (id) => users[id],
      jwtLifeSpan: jwtLifeSpan,
      allowTokenInQuery: allowTokenInQuery,
      reviveGracePeriod: reviveGracePeriod,
      enforceIp: false,
    );
    auth.strategies['local'] = LocalAuthStrategy(
      (username, password) =>
          username == 'alice' && password == 'pässwörd' ? 'Alice' : null,
      allowBasic: true,
    );
  }

  Future<void> start() async {
    await app.configure(auth.configureServer);
    app.post('/login', auth.authenticate('local'));
    app.post('/logout', auth.logout());
    app.get('/me', (RequestContext req, ResponseContext res) async {
      return await req.container!.makeAsync<String?>();
    });
  }

  String jwt(AuthToken token) => token.serialize(auth.hmac);

  Future<Got> send(
    String method,
    String path, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    var rq = MockHttpRequest(method, Uri.parse(path));
    rq.headers.add('accept', 'application/json');
    headers.forEach(rq.headers.add);
    if (body != null) {
      rq.headers.contentType = ContentType.json;
      rq.write(json.encode(body));
    }
    await rq.close();
    await http.handleRequest(rq);
    var text = await rq.response.transform(utf8.decoder).join();
    Object? decoded;
    try {
      decoded = json.decode(text);
    } on FormatException {
      decoded = text;
    }
    return (
      status: rq.response.statusCode,
      body: decoded,
      cookies: rq.response.cookies,
    );
  }
}

void main() {
  group('revival', () {
    test('of an expired JWT is refused', () async {
      var site = Site(jwtLifeSpan: 1000);
      await site.start();
      var old = AuthToken(
        userId: 'alice',
        lifeSpan: 1000,
        issuedAt: DateTime.now().subtract(const Duration(days: 7)),
      );
      var got = await site.send(
        'POST',
        '/auth/token',
        headers: {'authorization': 'Bearer ${site.jwt(old)}'},
      );
      expect(got.status, 403);
    });

    test('of a valid JWT gives a new one', () async {
      var site = Site(jwtLifeSpan: 60000);
      await site.start();
      var issued = DateTime.now().subtract(const Duration(seconds: 30));
      var current = AuthToken(
        userId: 'alice',
        lifeSpan: 60000,
        issuedAt: issued,
      );
      var got = await site.send(
        'POST',
        '/auth/token',
        headers: {'authorization': 'Bearer ${site.jwt(current)}'},
      );
      expect(got.status, 200);
      var fresh = AuthToken.parse((got.body as Map)['token'] as String);
      expect(fresh.issuedAt.isAfter(issued), isTrue);
      expect((got.body as Map)['data'], 'Alice');
    });

    test('within the grace period of an expired JWT is allowed', () async {
      var site = Site(
        jwtLifeSpan: 1000,
        reviveGracePeriod: const Duration(hours: 1),
      );
      await site.start();
      var old = AuthToken(
        userId: 'alice',
        lifeSpan: 1000,
        issuedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      var got = await site.send(
        'POST',
        '/auth/token',
        body: {'token': site.jwt(old)},
      );
      expect(got.status, 200);
    });

    test('of a JWT of a user that no longer exists is refused', () async {
      var site = Site();
      await site.start();
      var got = await site.send(
        'POST',
        '/auth/token',
        headers: {
          'authorization': 'Bearer ${site.jwt(AuthToken(userId: 'gone'))}',
        },
      );
      expect(got.status, 403);
    });
  });

  group('defaults', () {
    test('a JWT expires after a day', () async {
      var site = Site();
      await site.start();
      var got = await site.send(
        'POST',
        '/login',
        body: {'username': 'alice', 'password': 'pässwörd'},
      );
      var token = AuthToken.parse((got.body as Map)['token'] as String);
      expect(token.lifeSpan, const Duration(days: 1).inMilliseconds);
    });

    test('JWTs that never expire with a fixed key are warned about', () {
      var warnings = <String>[];
      var sub = Logger.root.onRecord
          .where((r) => r.level == Level.WARNING)
          .listen((r) => warnings.add(r.message));
      addTearDown(sub.cancel);
      Site(jwtLifeSpan: -1);
      expect(warnings, contains(contains('never expire')));
    });

    test('the cookie is SameSite=Lax', () async {
      var site = Site();
      await site.start();
      var got = await site.send(
        'POST',
        '/login',
        body: {'username': 'alice', 'password': 'pässwörd'},
      );
      var cookie = got.cookies.singleWhere((c) => c.name == 'token');
      expect(cookie.sameSite, SameSite.lax);
      expect(cookie.httpOnly, isTrue);
    });

    test('a Bearer JWT is not put in a cookie', () async {
      var site = Site();
      await site.start();
      var got = await site.send(
        'GET',
        '/me',
        headers: {
          'authorization': 'bearer ${site.jwt(AuthToken(userId: 'bob'))}',
        },
      );
      expect((got.status, got.body), (200, 'Bob'));
      expect(got.cookies.where((c) => c.name == 'token'), isEmpty);
    });

    test('a JWT in the query string is ignored unless allowed', () async {
      var site = Site();
      await site.start();
      var jwt = site.jwt(AuthToken(userId: 'bob'));
      expect((await site.send('GET', '/me?token=$jwt')).status, 403);

      var allowing = Site(allowTokenInQuery: true);
      await allowing.start();
      jwt = allowing.jwt(AuthToken(userId: 'bob'));
      expect((await allowing.send('GET', '/me?token=$jwt')).body, 'Bob');
    });
  });

  test('onLogin is a broadcast stream', () async {
    var site = Site();
    await site.start();
    var a = site.auth.onLogin.first, b = site.auth.onLogin.first;
    await site.send(
      'POST',
      '/login',
      body: {'username': 'alice', 'password': 'pässwörd'},
    );
    expect(await a, 'Alice');
    expect(await b, 'Alice');
  });

  test('logout expires the cookie', () async {
    var site = Site();
    await site.start();
    var got = await site.send('POST', '/logout');
    var cookie = got.cookies.singleWhere((c) => c.name == 'token');
    expect(cookie.value, isEmpty);
    expect(cookie.maxAge, 0);
    expect(cookie.expires!.isBefore(DateTime.now()), isTrue);
  });

  group('a malformed JWT is a 401, not a server error', () {
    late Site site;

    setUp(() async {
      site = Site();
      await site.start();
    });

    String signed(String payload) {
      var header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      var data = '$header.${base64Url.encode(utf8.encode(payload))}';
      return '$data.${base64Url.encode(site.auth.hmac.convert(data.codeUnits).bytes)}';
    }

    for (var (name, jwt) in [
      ('not base64', (Site s) => 'a.b!c.d'),
      ('of a bad length', (Site s) => 'a.bbbbb.c'),
      ('not JSON', (Site s) => 'x.${base64Url.encode(utf8.encode('nope'))}.y'),
    ]) {
      test(name, () async {
        var got = await site.send(
          'GET',
          '/me',
          headers: {'authorization': 'Bearer ${jwt(site)}'},
        );
        expect(got.status, anyOf(401, 403));
      });
    }

    test('signed, without a subject', () async {
      var got = await site.send(
        'GET',
        '/me',
        headers: {'authorization': 'Bearer ${signed('{"iat": 1}')}'},
      );
      expect(got.status, 401);
    });
  });

  group('tokens', () {
    test('have standard iat and exp claims, in seconds', () {
      var issued = DateTime.utc(2026, 1, 1);
      var token = AuthToken(userId: 'a', lifeSpan: 60000, issuedAt: issued);
      var claims = token.toJson();
      expect(claims['iat'], issued.millisecondsSinceEpoch / 1000);
      expect(claims['exp'], issued.millisecondsSinceEpoch / 1000 + 60);
      var read = AuthToken.fromMap(claims);
      expect(read.lifeSpan, 60000);
      expect(read.issuedAt.isAtSameMomentAs(issued), isTrue);
    });

    test('of a JWT before 10.0.0 are read', () {
      var read = AuthToken.fromMap({
        'sub': 'a',
        'iat': '2026-01-01T00:00:00.000',
        'exp': 60000,
        'aud': null,
      });
      expect(read.lifeSpan, 60000);
      expect(read.ipAddress, isNull);
    });
  });

  group('local', () {
    late Site site;

    setUp(() async {
      site = Site();
      await site.start();
    });

    test('a form login works with allowBasic', () async {
      var got = await site.send(
        'POST',
        '/login',
        body: {'username': 'alice', 'password': 'pässwörd'},
      );
      expect(got.status, 200);
    });

    test('Basic credentials are UTF-8', () async {
      var credentials = base64.encode(utf8.encode('alice:pässwörd'));
      var got = await site.send(
        'POST',
        '/login',
        headers: {'authorization': 'Basic $credentials'},
      );
      expect(got.status, 200);
    });

    test('a malformed Basic header is a 400', () async {
      var got = await site.send(
        'POST',
        '/login',
        headers: {'authorization': 'Basic %%%'},
      );
      expect(got.status, 400);
    });
  });
}
