import 'dart:convert';
import 'dart:io' show ContentType, Cookie, SameSite;

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_auth_client/angel3_auth_client.dart';
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
  // Of a token endpoint that answers with an error page of its own.
  var errorPage = false;
  var loginTimeout = const Duration(minutes: 10);

  setUp(() async {
    errors = [];
    tokenRequests = [];
    unreachable = false;
    errorPage = false;
    provider = MockClient((request) async {
      if (unreachable) throw http.ClientException('down', request.url);
      if (errorPage) {
        return http.Response(
          '<html>Down for maintenance</html>',
          503,
          headers: {'content-type': 'text/html'},
        );
      }
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

  Future<Got> get(
    String path, {
    Cookie? cookie,
    List<Cookie> cookies = const [],
  }) async {
    var rq = MockHttpRequest('GET', Uri.parse(path))
      ..headers.add('accept', 'application/json');
    // As a browser sends them back.
    for (var c in [?cookie, ...cookies]) {
      rq.cookies.add(Cookie(c.name, c.value));
    }
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

  test('a callback of a state no strategy gives, as of a crafted link, is '
      'invalid_state, not a 500', () async {
    for (var state in ['aaaaaaaaaaaa;b', 'a b/c=d' * 5, 'é' * 32]) {
      var got = await get(
        Uri(
          path: '/auth/callback',
          queryParameters: {'code': 'c', 'state': state},
        ).toString(),
      );
      expect(got.status, 400, reason: state);
      // Of onError, not of an error of the framework.
      expect(got.body, {'error': 'invalid_state'}, reason: state);
    }
    expect(errors, ['invalid_state', 'invalid_state', 'invalid_state']);
  });

  group('the logins of a browser', () {
    /// The cookies of a browser, by name: each sent only to the paths of
    /// its own (RFC 6265 §5.1.4), and replaced or removed as the responses
    /// set them.
    late Map<String, Cookie> jar;

    /// The names of the cookies that responses expired.
    late List<String> expiredNames;

    setUp(() {
      jar = {};
      expiredNames = [];
    });

    bool sentTo(Cookie cookie, String path) {
      var scope = cookie.path ?? '/';
      return path == scope ||
          (path.startsWith(scope) &&
              (scope.endsWith('/') || path[scope.length] == '/'));
    }

    Future<Got> browse(String url) async {
      var path = Uri.parse(url).path;
      var got = await get(
        url,
        cookies: [
          for (var c in jar.values)
            if (sentTo(c, path)) c,
        ],
      );
      for (var c in got.cookies) {
        if (c.maxAge == 0 && c.value.isEmpty) {
          expiredNames.add(c.name);
          // Removed only of the path it was set of.
          if (jar[c.name]?.path == c.path) jar.remove(c.name);
        } else {
          jar[c.name] = c;
        }
      }
      return got;
    }

    Iterable<String> logins() =>
        jar.keys.where((name) => name.startsWith('angel3_oauth2_'));

    test('are of a cookie of the path the start shares with the callback, '
        'which the start is sent', () async {
      await browse('/auth/start');
      expect(jar.values.single.path, '/auth');
      expect(sentTo(jar.values.single, '/auth/start'), isTrue);
      expect(sentTo(jar.values.single, '/auth/callback'), isTrue);
    });

    test('are at most maxLogins, the oldest expired as more start', () async {
      var started = <String>[];
      for (var i = 0; i < 7; i++) {
        var got = await browse('/auth/start');
        started.add(got.cookies.singleWhere((c) => c.value.isNotEmpty).name);
        // So that the logins are of distinct times.
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(logins(), unorderedEquals(started.skip(2)));
    });

    test(
      'are fewer once one is done: it, and the oldest beyond, expire',
      () async {
        // Seven, as of a start that is not sent them, so that only the
        // callback can expire them.
        var states = <String>[];
        for (var i = 0; i < 7; i++) {
          var got = await get('/auth/start');
          var cookie = got.cookies.single;
          jar[cookie.name] = cookie;
          states.add(Uri.parse(got.location!).queryParameters['state']!);
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        var got = await browse(
          Uri(
            path: '/auth/callback',
            queryParameters: {'code': 'c', 'state': states.last},
          ).toString(),
        );
        expect(got.status, 200);
        // The newest is done, and four are kept, of at most maxLogins - 1.
        expect(logins(), hasLength(4));
        expect(
          logins(),
          isNot(contains('angel3_oauth2_${states.last.substring(0, 12)}')),
        );
      },
    );

    test('are not expired by a callback of no login of the browser', () async {
      for (var i = 0; i < 5; i++) {
        await browse('/auth/start');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      for (var query in [
        {'code': 'c'},
        {'code': 'c', 'state': 'x' * 32},
      ]) {
        var got = await browse(
          Uri(path: '/auth/callback', queryParameters: query).toString(),
        );
        expect(got.status, 400);
      }
      expect(logins(), hasLength(5));
      expect(expiredNames, isEmpty);
    });

    test('of a login that timed out is cleared, as it is refused', () async {
      var state = 'abcdefghijklmnop' * 2;
      var name = 'angel3_oauth2_${state.substring(0, 12)}';
      jar[name] = Cookie(
        name,
        signed({
          's': state,
          'v': 'v' * 64,
          't': DateTime.now()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'p': '/auth',
          'c': 'id',
        }),
      )..path = '/auth';
      var got = await browse('/auth/callback?code=c&state=$state');
      expect(got.body, {'error': 'invalid_state'});
      expect(jar, isNot(contains(name)));
    });

    test(
      'of another state of the same start are counted on a callback',
      () async {
        // Six, as of a start that is not sent them, one over maxLogins.
        var states = <String>[];
        for (var i = 0; i < 6; i++) {
          var got = await get('/auth/start');
          var cookie = got.cookies.single;
          jar[cookie.name] = cookie;
          states.add(Uri.parse(got.location!).queryParameters['state']!);
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
        var other = '${states.last.substring(0, 12)}${'x' * 20}';
        await browse('/auth/callback?code=c&state=$other');
        expect(logins(), hasLength(5));
      },
    );

    test('expire no cookie of another client, signed alike', () async {
      var state = 'zyxwvutsrqponmlk' * 2;
      var name = 'angel3_oauth2_${state.substring(0, 12)}';
      jar[name] = Cookie(
        name,
        signed({
          's': state,
          'v': 'v' * 64,
          // The oldest, so the first to go, if it were of this strategy.
          't': DateTime.now()
              .subtract(const Duration(minutes: 1))
              .millisecondsSinceEpoch,
          'p': '/auth',
          'c': 'another client',
        }),
      )..path = '/auth';
      for (var i = 0; i < 7; i++) {
        await browse('/auth/start');
      }
      expect(expiredNames, isNot(contains(name)));
    });

    test('expire no cookie of another strategy, of the same name', () async {
      jar['angel3_oauth2_foreignlogin1'] = Cookie(
        'angel3_oauth2_foreignlogin1',
        'not-of-this-strategy',
      )..path = '/auth';
      for (var i = 0; i < 7; i++) {
        await browse('/auth/start');
      }
      expect(jar, contains('angel3_oauth2_foreignlogin1'));
      expect(expiredNames, isNot(contains('angel3_oauth2_foreignlogin1')));
    });
  });

  test('repeated query parameters of the endpoint are kept', () async {
    var strategy = OAuth2Strategy<String>(
      ExternalAuthOptions(
        clientId: 'id',
        clientSecret: 'secret',
        redirectUri: 'https://app.example/cb',
      ),
      Uri.parse(
        'https://provider.example/authorize?resource=a&resource=b'
        '&prompt=login&prompt=select_account',
      ),
      tokenEndpoint,
      (client, req, res) => 'alice',
      (e, req, res) => null,
      authorizationParameters: {'prompt': 'consent'},
    );
    var app = Angel();
    app.get('/start', (req, res) => strategy.authenticate(req, res));
    var rq = MockHttpRequest('GET', Uri.parse('/start'));
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    var url = Uri.parse(rq.response.headers.value('location')!);
    expect(url.queryParametersAll['resource'], ['a', 'b']);
    // Of authorizationParameters, which replace those of the endpoint.
    expect(url.queryParametersAll['prompt'], ['consent']);
  });

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
      // Of /auth/start and /auth/callback, which it is sent both.
      expect(cookie.path, '/auth');
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

  test(
    'a refusal of a malformed error_uri goes to onError, not a 502',
    () async {
      var (url, cookie) = await start();
      var state = url.queryParameters['state']!;
      var got = await get(
        Uri(
          path: '/auth/callback',
          queryParameters: {
            'state': state,
            'error': 'access_denied',
            'error_uri': 'http://[bad',
          },
        ).toString(),
        cookie: cookie,
      );
      expect(got.status, 400);
      expect(errors, ['access_denied']);
      expect(tokenRequests, isEmpty);
    },
  );

  test('the cookie of a login lasts its whole loginTimeout', () async {
    var app = await mapApp(loginTimeout: const Duration(milliseconds: 1500));
    var rq = MockHttpRequest('GET', Uri.parse('/start'));
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    var cookie = rq.response.cookies.singleWhere(
      (c) => c.name.startsWith('angel3_oauth2_'),
    );
    expect(cookie.maxAge, 2);
  });

  test('a callback of no code is invalid_request', () async {
    var (url, cookie) = await start();
    var state = url.queryParameters['state'];
    var got = await get('/auth/callback?code=&state=$state', cookie: cookie);
    expect(got.status, 400);
    expect(errors, ['invalid_request']);
  });

  test('a token response that cannot be read, as an error page of the '
      'provider, is a 502', () async {
    errorPage = true;
    var (url, cookie) = await start();
    var state = url.queryParameters['state'];
    var got = await get(
      '/auth/callback?code=c0de&state=$state',
      cookie: cookie,
    );
    expect(got.status, 502);
    expect(errors, isEmpty);
  });

  test('a callback of another state of the same start ends no login', () async {
    var (url, cookie) = await start();
    var state = url.queryParameters['state']!;
    // The same first 12 characters, so the same cookie, but another state.
    var other = '${state.substring(0, 12)}${'x' * 20}';
    var got = await get(
      '/auth/callback?code=c0de&state=$other',
      cookie: cookie,
    );
    expect(errors, ['invalid_state']);
    expect(got.cookies.where((c) => c.name == cookie.name), isEmpty);
    // The login goes on.
    got = await get('/auth/callback?code=c0de&state=$state', cookie: cookie);
    expect(got.status, 200);
  });

  test('loginTimeout must be at least a second', () {
    expect(
      () => OAuth2Strategy<String>(
        ExternalAuthOptions(
          clientId: 'id',
          clientSecret: 'secret',
          redirectUri: 'https://app.example/cb',
        ),
        authorizationEndpoint,
        tokenEndpoint,
        (client, req, res) => 'alice',
        (e, req, res) => null,
        loginTimeout: const Duration(milliseconds: 900),
      ),
      throwsArgumentError,
    );
  });

  group('a login that timed out', () {
    // The shortest that is allowed.
    setUpAll(() => loginTimeout = const Duration(seconds: 1));
    tearDownAll(() => loginTimeout = const Duration(minutes: 10));

    test('is refused', () async {
      var (url, cookie) = await start();
      await Future.delayed(const Duration(milliseconds: 1100));
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
  bool basicAuth = true,
  Map<String, String> authorizationParameters = const {},
  String redirectUri = 'https://app.example/cb',
  Duration loginTimeout = const Duration(minutes: 10),
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
      redirectUri: redirectUri,
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
    basicAuth: basicAuth,
    authorizationParameters: authorizationParameters,
    loginTimeout: loginTimeout,
  );
  await app.configure(auth.configureServer);
  app
    ..get('/start', auth.authenticate('p'))
    ..post('/start', auth.authenticate('p'));
  var callback = auth.authenticate('p', AngelAuthOptions());
  if (post) {
    app.post('/cb', callback);
  } else {
    app.get('/cb', callback);
  }
  return app;
}

void moreTests() {
  test('maxLogins must be at least 1', () {
    expect(
      () => OAuth2Strategy<String>(
        ExternalAuthOptions(
          clientId: 'id',
          clientSecret: 'secret',
          redirectUri: 'https://app.example/cb',
        ),
        authorizationEndpoint,
        tokenEndpoint,
        (client, req, res) => 'alice',
        (e, req, res) => null,
        maxLogins: 0,
      ),
      throwsArgumentError,
    );
  });

  group('warns of settings', () {
    late List<String> warnings;

    setUp(() {
      warnings = [];
      var sub = Logger.root.onRecord
          .where((r) => r.level == Level.WARNING)
          .listen((r) => warnings.add(r.message));
      addTearDown(sub.cancel);
    });

    test('of form_post, of a cookie of SameSite.lax', () async {
      await mapApp(authorizationParameters: {'response_mode': 'form_post'});
      expect(warnings, contains(contains('form_post')));
    });

    test('of SameSite.none, of an http redirect URI', () async {
      await mapApp(
        cookieSameSite: SameSite.none,
        redirectUri: 'http://app.example/cb',
      );
      expect(warnings, contains(contains('must be Secure')));
    });

    test('of authorizationParameters that are dropped', () async {
      await mapApp(authorizationParameters: {'scope': 'openid', 'x': 'y'});
      expect(warnings, contains(contains('authorizationParameters scope')));
    });

    test('of form_post of the endpoint, of a cookie of SameSite.lax', () {
      OAuth2Strategy<String>(
        ExternalAuthOptions(
          clientId: 'id',
          clientSecret: 'secret',
          redirectUri: 'https://app.example/cb',
        ),
        Uri.parse('https://appleid.example/authorize?response_mode=form_post'),
        tokenEndpoint,
        (client, req, res) => 'alice',
        (e, req, res) => null,
      );
      expect(warnings, contains(contains('form_post')));
    });

    test('of none, by default', () async {
      await mapApp();
      expect(warnings, isEmpty);
    });
  });

  test('a posted callback whose body cannot be read goes to onError, of '
      'form_post', () async {
    var http = AngelHttp(
      await mapApp(
        cookieSameSite: SameSite.none,
        post: true,
        authorizationParameters: {'response_mode': 'form_post'},
      ),
    );
    var cb = MockHttpRequest('POST', Uri.parse('/cb'))
      ..headers.add('accept', 'application/json')
      ..headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
    cb.write('code=%E0%A4%A');
    await cb.close();
    await http.handleRequest(cb);
    expect(cb.response.statusCode, 400);
    expect(json.decode(await cb.response.transform(utf8.decoder).join()), {
      'error': 'invalid_request',
    });
  });

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

  test(
    'a posted body that is not UTF-8 goes to onError too, of form_post',
    () async {
      var http = AngelHttp(
        await mapApp(
          cookieSameSite: SameSite.none,
          post: true,
          authorizationParameters: {'response_mode': 'form_post'},
        ),
      );
      var cb = MockHttpRequest('POST', Uri.parse('/cb'))
        ..headers.add('accept', 'application/json')
        ..headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
        );
      cb.add([0x63, 0x6f, 0x64, 0x65, 0x3d, 0xff, 0xfe]);
      await cb.close();
      await http.handleRequest(cb);
      expect(cb.response.statusCode, 400);
      expect(json.decode(await cb.response.transform(utf8.decoder).join()), {
        'error': 'invalid_request',
      });
    },
  );

  test('a posted form that starts a login, whose body cannot be read, starts '
      'it, without form_post', () async {
    var http = AngelHttp(await mapApp());
    var rq = MockHttpRequest('POST', Uri.parse('/start'))
      ..headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
    rq.write('a=%E0%A4%A');
    await rq.close();
    await http.handleRequest(rq);
    expect(rq.response.statusCode, 302);
    expect(
      rq.response.headers.value('location'),
      startsWith('$authorizationEndpoint'),
    );
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

  test('the authorization URL has the parameters asked for, but not in '
      'place of its own', () async {
    var app = await mapApp(
      authorizationParameters: {
        'response_mode': 'form_post',
        'prompt': 'consent',
        'state': 'mine',
        'client_id': 'other',
        'scope': 'admin',
      },
    );
    var rq = MockHttpRequest('GET', Uri.parse('/start'));
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    var url = Uri.parse(rq.response.headers.value('location')!);
    expect(url.queryParameters, containsPair('response_mode', 'form_post'));
    expect(url.queryParameters, containsPair('prompt', 'consent'));
    expect(url.queryParameters['state'], hasLength(32));
    expect(url.queryParameters['client_id'], 'id');
    // Of no scopes, which the grant leaves out.
    expect(url.queryParameters, isNot(contains('scope')));
  });

  for (var basicAuth in [true, false]) {
    test('the client secret is sent to the token endpoint '
        '${basicAuth ? 'with Basic authentication' : 'in the form'}', () async {
      late http.Request exchange;
      var provider = MockClient((request) async {
        exchange = request;
        return http.Response(
          json.encode({'access_token': 'at', 'token_type': 'bearer'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      var got = await logIn(
        await mapApp(provider: provider, basicAuth: basicAuth),
        (state) => {'code': 'c0de', 'state': state},
      );
      expect(got.status, 200);
      var form = Uri.splitQueryString(exchange.body);
      if (basicAuth) {
        expect(
          exchange.headers['authorization'],
          'Basic ${base64.encode(utf8.encode('id:secret'))}',
        );
        expect(form, isNot(contains('client_secret')));
      } else {
        expect(exchange.headers, isNot(contains('authorization')));
        expect(form, containsPair('client_id', 'id'));
        expect(form, containsPair('client_secret', 'secret'));
      }
    });
  }

  for (var basicAuth in [true, false]) {
    test('a client without a secret sends its id alone '
        '${basicAuth ? 'by default' : 'in the form'}', () async {
      late http.Request exchange;
      var provider = MockClient((request) async {
        exchange = request;
        return http.Response(
          json.encode({'access_token': 'at', 'token_type': 'bearer'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      var got = await logIn(
        await mapApp(
          clientSecret: '',
          provider: provider,
          basicAuth: basicAuth,
        ),
        (state) => {'code': 'c0de', 'state': state},
      );
      expect(got.status, 200);
      var form = Uri.splitQueryString(exchange.body);
      expect(exchange.headers, isNot(contains('authorization')));
      expect(form, containsPair('client_id', 'id'));
      expect(form, isNot(contains('client_secret')));
    });
  }

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
    // The prefix of the default key, of the former name of the package.
    var forgedKey = sha256.convert(utf8.encode('angel3_auth_oauth2:')).bytes;
    // Of the form of a state of the strategy, so that only its signature
    // can refuse it.
    var state = 'abcdefghijklmnop' * 2;
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

/// [claims], signed as the strategy of the tests, of the client secret
/// `secret`, signs the cookie of a login.
String signed(Map<String, Object> claims) {
  var key = sha256.convert(utf8.encode('angel3_auth_oauth2:secret')).bytes;
  var data = base64Url
      .encode(utf8.encode(json.encode(claims)))
      .replaceAll('=', '');
  var signature = base64Url
      .encode(Hmac(sha256, key).convert(ascii.encode(data)).bytes)
      .replaceAll('=', '');
  return '$data.$signature';
}
