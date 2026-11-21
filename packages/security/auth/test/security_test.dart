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
typedef Got = ({
  int status,
  Object? body,
  List<Cookie> cookies,
  HttpHeaders headers,
});

class Site {
  final Angel app = Angel();
  late final AngelHttp http = AngelHttp(app);
  late final AngelAuth<String?> auth;

  Site({
    num? jwtLifeSpan,
    bool allowTokenInQuery = false,
    Duration reviveGracePeriod = Duration.zero,
    String? jwtKey = 'key',
    AngelAuth<String?>? sharing,
  }) {
    if (sharing != null) {
      auth = sharing;
      return;
    }
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
      headers: rq.response.headers,
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

  group('an AngelAuth of two apps', () {
    var credentials = {'username': 'alice', 'password': 'pässwörd'};

    test('tells of logins until the last app shuts down', () async {
      var a = Site();
      var b = Site(sharing: a.auth);
      await a.start();
      await b.start();
      var logins = <String?>[];
      var done = false;
      a.auth.onLogin.listen(logins.add, onDone: () => done = true);

      await a.http.close();
      await b.send('POST', '/login', body: credentials);
      await Future<void>.delayed(Duration.zero);
      expect(logins, ['Alice']);
      expect(done, isFalse);

      await b.http.close();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });

    test('warns once of logins it can no longer tell of', () async {
      var a = Site();
      await a.start();
      await a.http.close();
      // Configured again, of a new app, once its streams are closed.
      var b = Site(sharing: a.auth);
      await b.start();

      var warnings = <String>[];
      var sub = Logger('AngelAuth').onRecord
          .where((r) => r.level == Level.WARNING)
          .map((r) => r.message)
          .where((m) => m.contains('was dropped'))
          .listen(warnings.add);
      for (var i = 0; i < 2; i++) {
        var got = await b.send('POST', '/login', body: credentials);
        expect(got.status, 200);
      }
      await sub.cancel();
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('onLogin'));
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

    test(
      'are issued by angel3_auth; a JWT of angel_auth is still read',
      () async {
        expect(AuthToken(userId: 'a').toJson()['iss'], 'angel3_auth');

        var site = Site();
        await site.start();
        // A JWT that 10.0.0 issued, of the old `iss`, signed as it was.
        var header = base64Url.encode(
          utf8.encode('{"alg":"HS256","typ":"JWT"}'),
        );
        var payload = base64Url.encode(
          utf8.encode(
            json.encode({
              ...AuthToken(userId: 'alice').toJson(),
              'iss': 'angel_auth',
            }),
          ),
        );
        var data = '$header.$payload';
        var signature = base64Url.encode(
          site.auth.hmac.convert(data.codeUnits).bytes,
        );
        var got = await site.send(
          'GET',
          '/me',
          headers: {'authorization': 'Bearer $data.$signature'},
        );
        expect(got.status, 200);
        expect(got.body, 'Alice');
      },
    );

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

  group('fixes', () {
    late Site site;
    var otherRan = false;

    setUp(() async {
      otherRan = false;
      site = Site();
      site.auth.strategies['other'] = _Recording(() => otherRan = true);
      site.auth.strategies['key'] = _ApiKey();
      await site.start();
      site.app
        ..get(
          '/basic',
          (req, res) => 'in',
          middleware: [forceBasicAuth<String?>()],
        )
        ..post('/chain', site.auth.authenticate(['local', 'other']))
        ..post('/keyed', site.auth.authenticate(['local', 'key']))
        ..post(
          '/login-redirect',
          site.auth.authenticate(
            'local',
            AngelAuthOptions(successRedirect: '/'),
          ),
        )
        ..post(
          '/logout-redirect',
          (req, res) => res.write('bye'),
          middleware: [
            site.auth.logout(AngelAuthOptions(successRedirect: '/')),
          ],
        )
        ..get('/as/:id', (RequestContext req, ResponseContext res) async {
          await site.auth.loginById(req.params['id'] as String, req, res);
          return 'ok';
        })
        ..post(
          '/refused',
          site.auth.authenticate(
            'local',
            AngelAuthOptions(
              tokenCallback: (req, res, token, user) =>
                  throw AngelHttpException.forbidden(),
            ),
          ),
        )
        ..post(
          '/again',
          site.auth.authenticate('local'),
          middleware: [requireAuthentication<String?>()],
        )
        ..get('/optional', (RequestContext req, ResponseContext res) async {
          // Called as a function, of `throwError: false`.
          Function handler = requireAuthentication<String?>();
          return {'ok': await handler(req, res, throwError: false)};
        })
        ..get('/popup', (RequestContext req, ResponseContext res) {
          return confirmPopupAuthentication(eventName: '</script>x')(
            req,
            res,
            'jwt',
          );
        });
    });

    test('forceBasicAuth refuses an expired JWT, not challenges it', () async {
      var jwt = site.jwt(
        AuthToken(
          userId: 'alice',
          lifeSpan: 1000,
          issuedAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
      );
      var got = await site.send(
        'GET',
        '/basic',
        headers: {'authorization': 'Bearer $jwt'},
      );
      expect(got.status, 403);
    });

    test(
      'requireAuthentication of throwError: false is false of no JWT',
      () async {
        expect((await site.send('GET', '/optional')).body, {'ok': false});
      },
    );

    test('onLogin is not told of a login that tokenCallback refuses, nor of '
        'a user signed in already', () async {
      var logins = <String?>[];
      var sub = site.auth.onLogin.listen(logins.add);
      var credentials = {'username': 'alice', 'password': 'pässwörd'};
      expect(
        (await site.send('POST', '/refused', body: credentials)).status,
        403,
      );
      var jwt = site.jwt(AuthToken(userId: 'alice'));
      expect(
        (await site.send(
          'POST',
          '/again',
          headers: {'authorization': 'Bearer $jwt'},
          body: credentials,
        )).status,
        200,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(logins, isEmpty);
    });

    test('forceBasicAuth challenges a request of no JWT', () async {
      var got = await site.send('GET', '/basic');
      expect(got.status, 401);
      expect(
        got.headers.value('www-authenticate'),
        'Basic realm="angel3_auth"',
      );
      var jwt = site.jwt(AuthToken(userId: 'alice'));
      got = await site.send(
        'GET',
        '/basic',
        headers: {'authorization': 'Bearer $jwt'},
      );
      expect(got.status, 200);
    });

    test(
      'the strategy after local is tried, of no or wrong credentials',
      () async {
        for (var body in [
          null,
          {'username': 'alice', 'password': 'wrong'},
        ]) {
          var got = await site.send(
            'POST',
            '/keyed',
            headers: {'x-api-key': 'k'},
            body: body,
          );
          expect(got.status, 200, reason: '$body');
          expect((got.body as Map)['data'], 'Alice');
        }
        // Of no key either, a 401, of the last strategy.
        expect((await site.send('POST', '/keyed')).status, 401);
      },
    );

    test('no strategy runs after one that answered the request', () async {
      var got = await site.send(
        'POST',
        '/chain',
        headers: {
          'authorization': 'Basic ${base64.encode(utf8.encode('alice:x'))}',
        },
      );
      expect(got.status, 401);
      expect(otherRan, isFalse);
    });

    test('onLogin is told of a login of a redirect', () async {
      var login = site.auth.onLogin.first;
      var got = await site.send(
        'POST',
        '/login-redirect',
        body: {'username': 'alice', 'password': 'pässwörd'},
      );
      expect(got.status, 302);
      expect(await login.timeout(Duration(seconds: 1)), 'Alice');
    });

    test('no handler runs after a logout that redirected', () async {
      var got = await site.send('POST', '/logout-redirect');
      expect(got.status, 302);
      expect(got.body, isNot(contains('bye')));
    });

    test('loginById of a user that does not exist is a 403', () async {
      expect((await site.send('GET', '/as/alice')).status, 200);
      expect((await site.send('GET', '/as/nobody')).status, 403);
    });

    test('the popup page escapes its event name', () async {
      var got = await site.send('GET', '/popup');
      expect(got.body, isNot(contains('</script>x')));
      // Of `<` as a JSON escape: a backslash, then `u003c`.
      var backslash = String.fromCharCode(92);
      expect(got.body, contains('"${backslash}u003c/script>x"'));
    });
  });

  test('configureServer may be called again', () async {
    var site = Site();
    await site.start();
    await site.app.configure(site.auth.configureServer);
  });

  test(
    'configureServer of another instance, of the same user, throws',
    () async {
      var site = Site();
      await site.start();
      expect(
        () => site.app.configure(Site().auth.configureServer),
        throwsStateError,
      );
    },
  );
}

/// A strategy that records that it ran, and authenticates no one.
class _Recording extends AuthStrategy<String?> {
  final void Function() ran;

  _Recording(this.ran);

  @override
  Future<String?> authenticate(
    RequestContext req,
    ResponseContext res, [
    AngelAuthOptions<String?>? options,
  ]) async {
    ran();
    return null;
  }
}

/// A strategy of the `x-api-key` header, of Alice's key, `k`.
class _ApiKey extends AuthStrategy<String?> {
  @override
  String? authenticate(
    RequestContext req,
    ResponseContext res, [
    AngelAuthOptions<String?>? options,
  ]) => req.headers?.value('x-api-key') == 'k' ? 'Alice' : null;
}
