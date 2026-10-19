import 'dart:convert';
import 'dart:io' show Cookie, SameSite;

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_auth_oauth2/angel3_auth_oauth2.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

final authorizationEndpoint = Uri.parse('https://provider.example/authorize');
final tokenEndpoint = Uri.parse('https://provider.example/token');

/// A response to a test request.
typedef Got = ({
  int status,
  Object? body,
  String? location,
  List<Cookie> cookies,
});

void main() {
  late AngelHttp http_;
  late List<String> errors;
  late List<Map<String, String>> tokenRequests;
  late http.Client provider;
  var unreachable = false;
  var loginTimeout = const Duration(minutes: 10);

  setUp(() async {
    errors = [];
    tokenRequests = [];
    unreachable = false;
    provider = MockClient((request) async {
      if (unreachable) throw http.ClientException('down', request.url);
      tokenRequests.add(Uri.splitQueryString(request.body));
      return http.Response(
        json.encode({'access_token': 'at', 'token_type': 'bearer'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    var app = Angel();
    var auth = AngelAuth<String>(
      jwtKey: 'key',
      serializer: (user) => user,
      deserializer: (id) => id,
      enforceIp: false,
    );
    auth.strategies['provider'] = OAuth2Strategy<String>(
      ExternalAuthOptions(
        clientId: 'id',
        clientSecret: 'secret',
        redirectUri: 'https://app.example/auth/callback',
        scopes: ['profile'],
      ),
      authorizationEndpoint,
      tokenEndpoint,
      (client, req, res) => 'alice',
      (e, req, res) {
        errors.add(e.error);
        res.statusCode = 400;
        return {'error': e.error};
      },
      httpClient: provider,
      loginTimeout: loginTimeout,
    );
    await app.configure(auth.configureServer);
    app.get('/auth/start', auth.authenticate('provider'));
    app.get(
      '/auth/callback',
      auth.authenticate('provider', AngelAuthOptions<String>()),
    );
    http_ = AngelHttp(app);
  });

  Future<Got> get(String path, {Cookie? cookie}) async {
    var rq = MockHttpRequest('GET', Uri.parse(path))
      ..headers.add('accept', 'application/json');
    // As a browser sends it back.
    if (cookie != null) rq.cookies.add(Cookie(cookie.name, cookie.value));
    await rq.close();
    await http_.handleRequest(rq);
    var text = await rq.response.transform(utf8.decoder).join();
    Object? body;
    try {
      body = json.decode(text);
    } on FormatException {
      body = text;
    }
    return (
      status: rq.response.statusCode,
      body: body,
      location: rq.response.headers.value('location'),
      cookies: rq.response.cookies,
    );
  }

  /// Starts a login: the authorization URL, and the cookie of the login.
  Future<(Uri, Cookie)> start() async {
    var got = await get('/auth/start');
    expect(got.status, 302);
    return (
      Uri.parse(got.location!),
      got.cookies.singleWhere((c) => c.name == 'angel3_oauth2'),
    );
  }

  group('the start of a login', () {
    test('redirects to the provider, with state and PKCE', () async {
      var (url, cookie) = await start();
      expect(url.replace(query: '').toString(), '$authorizationEndpoint?');
      var query = url.queryParameters;
      expect(query['state'], hasLength(32));
      expect(query['code_challenge_method'], 'S256');
      expect(query['scope'], 'profile');
      expect(cookie.httpOnly, isTrue);
      expect(cookie.secure, isTrue);
      expect(cookie.sameSite, SameSite.lax);
      expect(cookie.path, '/auth/callback');
    });

    test('of each user has its own state and code challenge', () async {
      var (a, _) = await start();
      var (b, _) = await start();
      expect(a.queryParameters['state'], isNot(b.queryParameters['state']));
      expect(
        a.queryParameters['code_challenge'],
        isNot(b.queryParameters['code_challenge']),
      );
    });
  });

  group('the callback', () {
    test('signs the user in, with the code verifier of the login', () async {
      var (url, cookie) = await start();
      var state = url.queryParameters['state'];
      var got = await get(
        '/auth/callback?code=c0de&state=$state',
        cookie: cookie,
      );
      expect(got.status, 200);
      expect((got.body as Map)['data'], 'alice');

      var verifier = tokenRequests.single['code_verifier']!;
      var challenge = base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
      expect(url.queryParameters['code_challenge'], challenge);
      expect(tokenRequests.single['code'], 'c0de');
      // The cookie of the login is used once.
      var cleared = got.cookies.singleWhere((c) => c.name == 'angel3_oauth2');
      expect(cleared.maxAge, 0);
    });

    test('of no login started here is refused', () async {
      var got = await get('/auth/callback?code=c0de&state=forged');
      expect(got.status, 400);
      expect(errors, ['invalid_state']);
      expect(tokenRequests, isEmpty);
    });

    test('of another state is refused (login CSRF)', () async {
      var (_, cookie) = await start();
      var got = await get(
        '/auth/callback?code=c0de&state=other',
        cookie: cookie,
      );
      expect(got.status, 400);
      expect(errors, ['invalid_state']);
    });

    test('with a tampered cookie is refused', () async {
      var (url, cookie) = await start();
      var state = url.queryParameters['state'];
      var tampered = Cookie(
        cookie.name,
        '${cookie.value.split('.').first}.bad',
      );
      var got = await get(
        '/auth/callback?code=c0de&state=$state',
        cookie: tampered,
      );
      expect(got.status, 400);
      expect(errors, ['invalid_state']);
    });

    test('of a provider error goes to onError', () async {
      var (url, cookie) = await start();
      var state = url.queryParameters['state'];
      var got = await get(
        '/auth/callback?error=access_denied&state=$state',
        cookie: cookie,
      );
      expect(got.status, 400);
      expect(got.body, {'error': 'access_denied'});
      expect(errors, ['access_denied']);
    });

    test('is a 502 when the provider cannot be reached', () async {
      var (url, cookie) = await start();
      unreachable = true;
      var state = url.queryParameters['state'];
      var got = await get(
        '/auth/callback?code=c0de&state=$state',
        cookie: cookie,
      );
      expect(got.status, 502);
    });
  });

  group('a login that timed out', () {
    setUpAll(() => loginTimeout = Duration.zero);
    tearDownAll(() => loginTimeout = const Duration(minutes: 10));

    test('is refused', () async {
      var (url, cookie) = await start();
      await Future.delayed(const Duration(milliseconds: 5));
      var state = url.queryParameters['state'];
      var got = await get(
        '/auth/callback?code=c0de&state=$state',
        cookie: cookie,
      );
      expect(got.status, 400);
      expect(errors, ['invalid_state']);
    });
  });
}
