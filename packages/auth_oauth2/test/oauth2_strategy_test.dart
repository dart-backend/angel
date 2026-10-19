import 'dart:convert';
import 'dart:io' show ContentType, Cookie, SameSite;

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_auth_oauth2/angel3_auth_oauth2.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
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
  group('more', moreTests);
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
      got.cookies.singleWhere((c) => c.name.startsWith('angel3_oauth2_')),
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
      var cleared = got.cookies.singleWhere(
        (c) => c.name.startsWith('angel3_oauth2_'),
      );
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

/// A login of [strategy], of [app]: started, then called back with
/// [parameters], in the query, or posted as a form if [post].
Future<({int status, String body, List<Cookie> cookies})> logIn(
  Angel app,
  Map<String, String> Function(String state) parameters, {
  bool post = false,
  int starts = 1,
}) async {
  var http = AngelHttp(app);
  var logins = <(String, Cookie)>[];
  for (var i = 0; i < starts; i++) {
    var rq = MockHttpRequest('GET', Uri.parse('/start'));
    await rq.close();
    await http.handleRequest(rq);
    var state = Uri.parse(rq.response.headers.value('location')!)
        .queryParameters['state']!;
    logins.add((
      state,
      rq.response.cookies.singleWhere(
        (c) => c.name.startsWith('angel3_oauth2_'),
      ),
    ));
  }

  // The first login, with the cookies of all, as a browser of two tabs.
  var (state, _) = logins.first;
  var query = parameters(state);
  var cb = post
      ? MockHttpRequest('POST', Uri.parse('/cb'))
      : MockHttpRequest(
          'GET',
          Uri.parse('/cb').replace(queryParameters: query),
        );
  cb.headers.add('accept', 'application/json');
  for (var (_, cookie) in logins) {
    cb.cookies.add(Cookie(cookie.name, cookie.value));
  }
  if (post) {
    cb.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    cb.write(Uri(queryParameters: query).query);
  }
  await cb.close();
  await http.handleRequest(cb);
  return (
    status: cb.response.statusCode,
    body: await cb.response.transform(utf8.decoder).join(),
    cookies: cb.response.cookies,
  );
}

/// An app whose users are maps, of a strategy whose `onError` returns a map.
Future<Angel> mapApp({
  String clientSecret = 'secret',
  http.Client? provider,
  SameSite cookieSameSite = SameSite.lax,
  bool post = false,
}) async {
  var app = Angel();
  var auth = AngelAuth<Map<String, dynamic>>(
    jwtKey: 'key',
    serializer: (user) => '${user['id']}',
    deserializer: (id) => {'id': id},
    enforceIp: false,
  );
  auth.strategies['p'] = OAuth2Strategy<Map<String, dynamic>>(
    ExternalAuthOptions(
      clientId: 'id',
      clientSecret: clientSecret,
      redirectUri: 'https://app.example/cb',
    ),
    authorizationEndpoint,
    tokenEndpoint,
    (client, req, res) => {'id': 'alice'},
    (e, req, res) {
      res.statusCode = 400;
      return <String, dynamic>{'error': e.error};
    },
    httpClient:
        provider ??
        MockClient(
          (request) async => http.Response(
            json.encode({'access_token': 'at', 'token_type': 'bearer'}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
    cookieSameSite: cookieSameSite,
  );
  await app.configure(auth.configureServer);
  app.get('/start', auth.authenticate('p'));
  var callback = auth.authenticate('p', AngelAuthOptions());
  if (post) {
    app.post('/cb', callback);
  } else {
    app.get('/cb', callback);
  }
  return app;
}

void moreTests() {
  test('an error of onError, of map users, is no login', () async {
    var got = await logIn(
      await mapApp(),
      (state) => {'error': 'access_denied', 'state': state},
    );
    expect(got.status, 400);
    expect(json.decode(got.body), {'error': 'access_denied'});
    expect(got.cookies.where((c) => c.name == 'token'), isEmpty);
  });

  test('a user of the verifier, of map users, is a login', () async {
    var got = await logIn(
      await mapApp(),
      (state) => {'code': 'c0de', 'state': state},
    );
    expect(got.status, 200);
    expect((json.decode(got.body) as Map)['data'], {'id': 'alice'});
  });

  test('a posted callback (form_post) is a login', () async {
    var got = await logIn(
      await mapApp(cookieSameSite: SameSite.none, post: true),
      (state) => {'code': 'c0de', 'state': state},
      post: true,
    );
    expect(got.status, 200);
  });

  test('the cookie of a login is of the SameSite asked for', () async {
    var app = await mapApp(cookieSameSite: SameSite.none);
    var rq = MockHttpRequest('GET', Uri.parse('/start'));
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    var cookie = rq.response.cookies.singleWhere(
      (c) => c.name.startsWith('angel3_oauth2_'),
    );
    expect(cookie.sameSite, SameSite.none);
    expect(cookie.secure, isTrue);
  });

  test('two logins at once, as in two tabs, each work', () async {
    var got = await logIn(
      await mapApp(),
      (state) => {'code': 'c0de', 'state': state},
      starts: 2,
    );
    expect(got.status, 200);
  });

  test('a client without a secret signs with a random key', () async {
    var warnings = <String>[];
    var sub = Logger.root.onRecord
        .where((r) => r.level == Level.WARNING)
        .listen((r) => warnings.add(r.message));
    addTearDown(sub.cancel);
    var app = await mapApp(clientSecret: '');
    expect(warnings, contains(contains('no secret')));
    // A cookie signed with the key of the empty secret is refused.
    var forgedKey = sha256.convert(utf8.encode('angel3_auth_oauth2:')).bytes;
    var state = 'abcdefghijklmnop';
    var data = base64Url
        .encode(
          utf8.encode(
            json.encode({
              's': state,
              'v': 'v' * 64,
              't': DateTime.now().millisecondsSinceEpoch,
            }),
          ),
        )
        .replaceAll('=', '');
    var signature = base64Url
        .encode(Hmac(sha256, forgedKey).convert(ascii.encode(data)).bytes)
        .replaceAll('=', '');
    var cb = MockHttpRequest('GET', Uri.parse('/cb?code=c0de&state=$state'))
      ..cookies.add(
        Cookie('angel3_oauth2_${state.substring(0, 12)}', '$data.$signature'),
      );
    await cb.close();
    await AngelHttp(app).handleRequest(cb);
    expect(cb.response.statusCode, 400);
  });
}
