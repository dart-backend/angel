/// Logins of [OAuth2Strategy] against a provider of `angel3_auth_server`,
/// over HTTP, as a browser would make them.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_auth_client/angel3_auth_client.dart';
import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:test/test.dart';

void main() {
  late _Sites sites;

  tearDown(() => sites.close());

  group('a confidential client', () {
    for (var basicAuth in [true, false]) {
      test('signs in, of its secret by '
          '${basicAuth ? 'Basic' : 'the form'}', () async {
        sites = await _Sites.start(basicAuth: basicAuth);
        var got = await sites.login();
        expect(got.status, 200, reason: got.body);
        var json = jsonDecode(got.body) as Map;
        expect(json['data'], 'alice');
        expect(json['token'], isA<String>());
        // Of the scopes, which the provider gave its token.
        expect(sites.provider.lastScopes, ['read', 'profile']);
        expect(sites.provider.lastByBasic, basicAuth);
      });
    }
  });

  test('a public client signs in, of PKCE alone', () async {
    sites = await _Sites.start(public: true);
    var got = await sites.login();
    expect(got.status, 200, reason: got.body);
    expect((jsonDecode(got.body) as Map)['data'], 'alice');
  });

  test('a login the user denies goes to onError', () async {
    sites = await _Sites.start(scopes: ['deny']);
    var got = await sites.login();
    expect(jsonDecode(got.body), {
      'error': 'access_denied',
      'description': 'The user denied access.',
    });
  });

  test('a callback of another state is refused by the client', () async {
    sites = await _Sites.start();
    var got = await sites.login(
      callback: (uri) => uri.replace(
        queryParameters: {...uri.queryParameters, 'state': 'x' * 32},
      ),
    );
    expect((jsonDecode(got.body) as Map)['error'], 'invalid_state');
  });

  test('a code is redeemed once', () async {
    sites = await _Sites.start();
    late Uri callback;
    late List<Cookie> cookies;
    var first = await sites.login(
      callback: (uri) => callback = uri,
      cookies: (c) => cookies = c,
    );
    expect(first.status, 200, reason: first.body);
    // The same callback, of the same login cookie, as a replay.
    var again = await _get(
      callback,
      cookies: cookies,
      accept: 'application/json',
    );
    expect((jsonDecode(again.body) as Map)['error'], 'invalid_grant');
  });

  test('a code of another login, of its verifier, is refused by the '
      'provider', () async {
    sites = await _Sites.start();
    // Two logins; the code of the second, of the state and cookie (so the
    // code verifier) of the first.
    var a = await _get(sites.loginUrl);
    var b = await _get(sites.loginUrl);
    var codeOfA = (await _get(a.location!)).location!;
    var codeOfB = (await _get(b.location!)).location!;
    var got = await _get(
      codeOfB.replace(
        queryParameters: {
          ...codeOfB.queryParameters,
          'state': codeOfA.queryParameters['state']!,
        },
      ),
      cookies: a.cookies,
      accept: 'application/json',
    );
    expect((jsonDecode(got.body) as Map)['error'], 'invalid_grant');
  });
}

/// A response to a request of [_get].
typedef _Got = ({int status, Uri? location, List<Cookie> cookies, String body});

/// GETs [uri], of [cookies], following no redirect, as each leg of a login
/// is a request of its own.
Future<_Got> _get(
  Uri uri, {
  List<Cookie> cookies = const [],
  String? accept,
}) async {
  var client = HttpClient();
  try {
    var request = await client.getUrl(uri);
    request.followRedirects = false;
    request.cookies.addAll(cookies);
    if (accept != null) request.headers.set('accept', accept);
    var response = await request.close();
    var location = response.headers.value('location');
    return (
      status: response.statusCode,
      location: location == null ? null : uri.resolve(location),
      cookies: response.cookies,
      body: await response.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}

/// The provider, of `angel3_auth_server`, and the app that signs users in
/// with it, of [OAuth2Strategy], each on a port of its own.
class _Sites {
  final _Provider provider;
  final AngelHttp _providerHttp, _appHttp;
  final Uri loginUrl;

  _Sites._(this.provider, this._providerHttp, this._appHttp, this.loginUrl);

  static Future<_Sites> start({
    bool basicAuth = true,
    bool public = false,
    List<String> scopes = const ['read', 'profile'],
  }) async {
    // The app's port is that of its redirect URI, which the provider
    // registers, so it is bound first.
    var appServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var appBase = Uri.parse('http://127.0.0.1:${appServer.port}');
    var redirectUri = appBase.resolve('/auth/callback');

    var provider = _Provider({
      'confidential': _App('confidential', 'pässwörd s3cret+', redirectUri),
      'public': _App('public', '', redirectUri),
    });
    var providerApp = Angel();
    providerApp
      ..get('/oauth2/authorize', provider.authorizationEndpoint)
      ..post('/oauth2/token', provider.tokenEndpoint)
      ..get(
        '/api/me',
        (RequestContext req, ResponseContext res) => {
          'user': req.container!.make<AccessToken<_App, String>>().user,
        },
        middleware: [
          provider.requireToken(scopes: ['read']),
        ],
      );
    providerApp.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    var providerHttp = AngelHttp(providerApp);
    var providerServer = await providerHttp.startServer('127.0.0.1', 0);
    var providerBase = Uri.parse('http://127.0.0.1:${providerServer.port}');

    var app = Angel();
    var auth = AngelAuth<String>(
      serializer: (user) => user,
      deserializer: (id) => id,
      jwtKey: 'interop',
      allowCookie: false,
    );
    await app.configure(auth.configureServer);
    var client = public
        ? provider.clients['public']!
        : provider.clients['confidential']!;
    auth.strategies['provider'] = OAuth2Strategy<String>(
      ExternalAuthOptions(
        clientId: client.id,
        clientSecret: client.secret,
        redirectUri: redirectUri,
        scopes: scopes,
      ),
      providerBase.resolve('/oauth2/authorize'),
      providerBase.resolve('/oauth2/token'),
      // Of the provider's API, of the token: RFC 6750 too.
      (client, req, res) async {
        var me = await client.get(providerBase.resolve('/api/me'));
        return (jsonDecode(me.body) as Map)['user'] as String;
      },
      (e, req, res) => {'error': e.error, 'description': e.description},
      basicAuth: basicAuth,
      cookieKey: public ? utf8.encode('interop cookie key') : null,
    );
    app
      ..get('/auth/login', auth.authenticate('provider'))
      ..get('/auth/callback', auth.authenticate('provider'));
    var appHttp = AngelHttp(app);
    unawaited(appHttp.startServer().then((_) {}));
    appServer.listen(appHttp.handleRequest);

    return _Sites._(
      provider,
      providerHttp,
      appHttp,
      appBase.resolve('/auth/login'),
    );
  }

  /// Signs in, as a browser would: to the app, redirected to the provider,
  /// which approves, and redirected back, of the app's login cookie. Of the
  /// URL of the callback, as [callback] changes it.
  Future<_Got> login({
    Uri Function(Uri)? callback,
    void Function(List<Cookie>)? cookies,
  }) async {
    var start = await _get(loginUrl);
    expect(start.status, 302);
    cookies?.call(start.cookies);
    var authorized = await _get(start.location!);
    expect(authorized.status, 302, reason: authorized.body);
    var back = authorized.location!;
    return _get(
      callback?.call(back) ?? back,
      cookies: start.cookies,
      accept: 'application/json',
    );
  }

  Future<void> close() async {
    await _providerHttp.close();
    await _appHttp.close();
  }
}

class _App {
  final String id, secret;
  final Uri redirectUri;

  _App(this.id, this.secret, this.redirectUri);
}

/// A code, as the provider stores it.
typedef _Code = ({
  _App client,
  Uri redirectUri,
  Pkce pkce,
  List<String> scopes,
});

/// A provider that approves every login as alice, but of the `deny` scope.
class _Provider extends AuthorizationServer<_App, String> {
  final Map<String, _App> clients;
  final _codes = <String, _Code>{};
  final _tokens = <String, AccessToken<_App, String>>{};
  final _random = Random.secure();

  /// The scopes of the last token.
  List<String>? lastScopes;

  /// Whether the last token request authenticated its client by Basic.
  bool? lastByBasic;

  _Provider(this.clients);

  String _randomString() =>
      base64Url.encode([for (var i = 0; i < 24; i++) _random.nextInt(256)]);

  @override
  _App? findClient(String? clientId) => clients[clientId];

  @override
  bool verifyClient(_App client, String? clientSecret) => client.secret.isEmpty
      ? clientSecret == null
      : client.secret == clientSecret;

  @override
  Uri? registeredRedirectUri(_App client, String? redirectUri) {
    if (redirectUri == null || redirectUri == '${client.redirectUri}') {
      return client.redirectUri;
    }
    throw AuthorizationException(
      ErrorResponse(
        ErrorResponse.invalidRequest,
        'The "redirect_uri" is not registered.',
        '',
      ),
    );
  }

  @override
  Future<void> requestAuthorizationCode(
    _App client,
    String? redirectUri,
    Iterable<String> scopes,
    String state,
    RequestContext req,
    ResponseContext res,
    bool implicit,
  ) async {
    if (scopes.contains('deny')) {
      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.accessDenied,
          'The user denied access.',
          state,
        ),
      );
    }
    var code = _randomString();
    _codes[code] = (
      client: client,
      redirectUri: Uri.parse(redirectUri!),
      // Of the request, which the server checked: S256, as it requires.
      pkce: req.container!.make<Pkce>(),
      scopes: scopes.toList(),
    );
    await res.redirect(
      completeAuthorizationCode(code, Uri.parse(redirectUri), state: state),
    );
  }

  @override
  Future<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
    _App? client,
    String? authCode,
    String? redirectUri,
    RequestContext req,
    ResponseContext res,
  ) async {
    // Used once, whatever comes of it.
    var stored = _codes.remove(authCode);
    if (stored == null ||
        stored.client != client ||
        (redirectUri != null && redirectUri != '${stored.redirectUri}')) {
      throw AuthorizationException(
        ErrorResponse(ErrorResponse.invalidGrant, 'The code is not valid.', ''),
      );
    }
    stored.pkce.validate(await getPkceCodeVerifier(req));

    var token = _randomString();
    _tokens[token] = AccessToken(
      client: client,
      user: 'alice',
      scopes: stored.scopes,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    lastScopes = stored.scopes;
    lastByBasic = req.headers?.value('authorization') != null;
    return AuthorizationTokenResponse(
      token,
      expiresIn: 3600,
      scope: stored.scopes,
    );
  }

  @override
  AccessToken<_App, String>? findAccessToken(
    String token,
    RequestContext req,
  ) => _tokens[token];
}
