/// Logins of [OAuth2Strategy], of OpenID Connect, against a provider of
/// `angel3_oidc_server`, over HTTP, as a browser would make them: of its
/// configuration, discovered, and of ID tokens of its keys.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_auth_client/angel3_auth_client.dart';
import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_oidc_server/angel3_oidc_server.dart';
import 'package:test/test.dart';

void main() {
  late OpenIdSigningKey key;
  late AngelHttp providerHttp, appHttp;
  late Uri loginUrl, signedOutUrl;
  late OpenIdProvider discovered;
  late _Provider provider;
  // The ID token of the last login, as an app keeps it for logout.
  String? lastIdToken;

  setUpAll(() => key = OpenIdSigningKey.generate(keyId: 'k1'));

  setUp(() async {
    // The app's port is that of its redirect URI, which the provider
    // registers, so it is bound first; the provider's, of its issuer.
    var appServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var providerServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var issuer = Uri.parse('http://localhost:${providerServer.port}');
    var redirectUri = Uri.parse(
      'http://127.0.0.1:${appServer.port}/auth/callback',
    );
    signedOutUrl = redirectUri.resolve('/signed-out');

    provider = _Provider(issuer, key, redirectUri, signedOutUrl);
    var providerApp = Angel();
    providerApp.group('/oauth2', (router) {
      router
        ..get('/authorize', provider.authorizationEndpoint)
        ..post('/token', provider.tokenEndpoint)
        ..get('/jwks', provider.jwksEndpoint)
        ..get('/userinfo', provider.userInfoEndpoint)
        ..get('/logout', provider.endSessionEndpoint);
    });
    providerApp.get(
      openIdConfigurationPath,
      provider.openIdConfigurationEndpoint(
        ServerMetadata(
          issuer: issuer,
          authorizationEndpoint: issuer.resolve('/oauth2/authorize'),
          tokenEndpoint: issuer.resolve('/oauth2/token'),
        ),
        jwksUri: issuer.resolve('/oauth2/jwks'),
        userInfoEndpoint: issuer.resolve('/oauth2/userinfo'),
        endSessionEndpoint: issuer.resolve('/oauth2/logout'),
      ),
    );
    providerApp.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    providerHttp = AngelHttp(providerApp);
    unawaited(providerHttp.startServer().then((_) {}));
    providerServer.listen(providerHttp.handleRequest);

    discovered = await OpenIdOptions.discover(issuer);
    var app = Angel();
    var auth = AngelAuth<String>(
      serializer: (user) => user,
      deserializer: (id) => id,
      jwtKey: 'interop',
      allowCookie: false,
    );
    await app.configure(auth.configureServer);
    auth.strategies['oidc'] = OAuth2Strategy<String>(
      ExternalAuthOptions(
        clientId: 'app',
        clientSecret: 'secret',
        redirectUri: redirectUri,
        scopes: ['openid', 'email'],
      ),
      discovered.authorizationEndpoint,
      discovered.tokenEndpoint,
      // Of the ID token, and of UserInfo, of its access token.
      (client, req, res) async {
        var idToken = req.container!.make<IdToken>();
        lastIdToken = idToken.token;
        var info = json.decode(await client.read(discovered.userInfoEndpoint!));
        return '${idToken.issuer}|${idToken.subject}|${info['email']}';
      },
      (e, req, res) => {'error': e.error, 'description': e.description},
      openId: discovered.openId,
    );
    app
      ..get('/auth/login', auth.authenticate('oidc'))
      ..get('/auth/callback', auth.authenticate('oidc'));
    appHttp = AngelHttp(app);
    unawaited(appHttp.startServer().then((_) {}));
    appServer.listen(appHttp.handleRequest);
    loginUrl = Uri.parse('http://127.0.0.1:${appServer.port}/auth/login');
  });

  tearDown(() async {
    await providerHttp.close();
    await appHttp.close();
  });

  test('a login of OpenID Connect gives the user of a checked ID token, and '
      'of UserInfo', () async {
    var start = await _get(loginUrl);
    expect(start.status, 302);
    expect(start.location!.queryParameters['nonce'], hasLength(32));
    var authorized = await _get(start.location!);
    expect(authorized.status, 302, reason: authorized.body);
    var back = await _get(
      authorized.location!,
      cookies: start.cookies,
      accept: 'application/json',
    );
    expect(back.status, 200, reason: back.body);
    var user = (json.decode(back.body) as Map)['data'] as String;
    // The provider's issuer, of the port of its authorization endpoint.
    var issuer = 'http://localhost:${start.location!.port}';
    expect(user, '$issuer|alice|alice@example.com');

    // Then signed out of the provider too, of the ID token of the login.
    var logout = discovered.endSessionUrl(
      idTokenHint: lastIdToken,
      postLogoutRedirectUri: signedOutUrl,
      state: 'bye',
    );
    var out = await _get(logout);
    expect(out.status, 302, reason: out.body);
    expect(
      out.location,
      signedOutUrl.replace(queryParameters: {'state': 'bye'}),
    );
    expect(provider.signedOut, ['alice']);
  });
}

typedef _Got = ({int status, Uri? location, List<Cookie> cookies, String body});

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

typedef _Code = ({List<String> scopes, OpenIdRequest openId, Pkce pkce});

/// A provider that signs `alice` in at once, for the client `app`.
class _Provider extends OpenIdServer<String, String> {
  final Uri redirectUri, signedOutUri;

  _Provider(
    Uri issuer,
    OpenIdSigningKey key,
    this.redirectUri,
    this.signedOutUri,
  ) : super(issuer: issuer, signingKeys: [key]);

  /// The subjects of the users who signed out.
  final signedOut = <String?>[];

  @override
  Iterable<Uri> postLogoutRedirectUrisOf(String client) => [signedOutUri];

  @override
  void endSession(
    EndSessionRequest<String> request,
    RequestContext req,
    ResponseContext res,
  ) => signedOut.add(request.subject);

  final _codes = <String, _Code>{};
  final _tokens = <String, AccessToken<String, String>>{};
  var _next = 0;

  @override
  String? findClient(String? clientId) => clientId == 'app' ? 'app' : null;

  @override
  bool verifyClient(String client, String? clientSecret) =>
      clientSecret == 'secret';

  @override
  Uri? registeredRedirectUri(String client, String? redirectUri) =>
      redirectUri == null || redirectUri == '${this.redirectUri}'
      ? this.redirectUri
      : throw AuthorizationException(
          ErrorResponse(ErrorResponse.invalidRequest, 'Unknown URI.', ''),
        );

  @override
  String clientIdOf(String client) => client;

  @override
  String subjectOf(String user) => user;

  @override
  Map<String, dynamic> claimsOf(String user) => {
    'email': '$user@example.com',
    'email_verified': true,
  };

  @override
  Future<void> requestAuthorizationCode(
    String client,
    String? redirectUri,
    Iterable<String> scopes,
    String state,
    RequestContext req,
    ResponseContext res,
    bool implicit,
  ) async {
    var code = 'code-${_next++}';
    _codes[code] = (
      scopes: scopes.toList(),
      openId: req.container!.make<OpenIdRequest>(),
      pkce: req.container!.make<Pkce>(),
    );
    await res.redirect(
      completeAuthorizationCode(code, Uri.parse(redirectUri!), state: state),
    );
  }

  @override
  Future<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
    String? client,
    String? authCode,
    String? redirectUri,
    RequestContext req,
    ResponseContext res,
  ) async {
    var stored = _codes.remove(authCode)!;
    stored.pkce.validate(await getPkceCodeVerifier(req));
    var accessToken = 'at-${_next++}';
    _tokens[accessToken] = AccessToken(
      client: client,
      user: 'alice',
      scopes: stored.scopes,
    );
    return IdTokenResponse(
      accessToken,
      scope: stored.scopes,
      idToken: issueIdToken(
        user: 'alice',
        client: client!,
        nonce: stored.openId.nonce,
        authTime: DateTime.now(),
        accessToken: accessToken,
      ),
    );
  }

  @override
  AccessToken<String, String>? findAccessToken(
    String token,
    RequestContext req,
  ) => _tokens[token];
}
