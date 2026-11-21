import 'dart:async';
import 'dart:io';

import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_oidc_server/angel3_oidc_server.dart';

/// An OpenID Provider on http://localhost:3000, which signs `alice` in at
/// once, for the client `app` of the secret `secret`:
///
/// ```sh
/// dart run example/main.dart
/// curl http://localhost:3000/.well-known/openid-configuration
/// ```
///
/// Its key is new of each run: in an app, store the `toJson` of a key, as a
/// secret, and load it with `OpenIdSigningKey.fromJwk`.
Future<void> main() async {
  var issuer = Uri.parse('http://localhost:3000');
  var server = _Provider(issuer, OpenIdSigningKey.generate(keyId: 'example-1'));

  var app = Angel();
  app.group('/oauth2', (router) {
    router
      ..get('/authorize', server.authorizationEndpoint)
      ..post('/authorize', server.authorizationEndpoint)
      ..post('/token', server.tokenEndpoint)
      ..get('/jwks', server.jwksEndpoint)
      ..get('/userinfo', server.userInfoEndpoint)
      ..post('/userinfo', server.userInfoEndpoint);
  });
  app.get(
    openIdConfigurationPath,
    server.openIdConfigurationEndpoint(
      ServerMetadata(
        issuer: issuer,
        authorizationEndpoint: issuer.resolve('/oauth2/authorize'),
        tokenEndpoint: issuer.resolve('/oauth2/token'),
      ),
      jwksUri: issuer.resolve('/oauth2/jwks'),
      userInfoEndpoint: issuer.resolve('/oauth2/userinfo'),
    ),
  );
  app.errorHandler = (e, req, res) async {
    res.statusCode = e.statusCode;
    res.json(e.toJson());
  };

  var http = AngelHttp(app);
  await http.startServer(InternetAddress.loopbackIPv4, 3000);
  print('Configuration: $issuer$openIdConfigurationPath');
}

class _Client {
  final String id, secret;
  final Uri redirectUri;
  const _Client(this.id, this.secret, this.redirectUri);
}

/// What a provider stores of a code, until it is exchanged.
typedef _Code = ({
  String user,
  String clientId,
  String? redirectUri,
  DateTime authTime,
  List<String> scopes,
  OpenIdRequest openId,
  Pkce pkce,
});

class _Provider extends OpenIdServer<_Client, String> {
  _Provider(Uri issuer, OpenIdSigningKey key)
    : super(issuer: issuer, signingKeys: [key]);

  final _client = _Client(
    'app',
    'secret',
    Uri.parse('http://localhost:8080/callback'),
  );
  final _codes = <String, _Code>{};
  final _tokens = <String, AccessToken<_Client, String>>{};
  var _next = 0;

  /// When alice signed in, of the session the app would keep: of this run.
  final _signedInAt = DateTime.now();

  @override
  _Client? findClient(String? clientId) =>
      clientId == _client.id ? _client : null;

  @override
  bool verifyClient(_Client client, String? clientSecret) =>
      client.secret == clientSecret;

  @override
  Uri? registeredRedirectUri(_Client client, String? redirectUri) =>
      client.redirectUri;

  @override
  String clientIdOf(_Client client) => client.id;

  @override
  String subjectOf(String user) => user;

  @override
  Map<String, dynamic> claimsOf(String user) => {
    'name': 'Alice',
    'email': '$user@example.com',
    'email_verified': true,
  };

  @override
  Future<void> requestAuthorizationCode(
    _Client client,
    String? redirectUri,
    Iterable<String> scopes,
    String state,
    RequestContext req,
    ResponseContext res,
    bool implicit,
  ) async {
    var openId = req.container!.make<OpenIdRequest>();
    // Here, an app reads its session: alice is signed in, and has consented.
    // Of prompt=none, this throws login_required and the like, which are
    // redirected; of what it gives, the app would prompt the user first.
    var needed = openId.interactions(
      signedIn: true,
      authTime: _signedInAt,
      consented: true,
    );
    if (needed.isNotEmpty) {
      res.write('Here, the user would be asked to: ${needed.join(', ')}.');
      return;
    }
    var code = 'code-${_next++}';
    _codes[code] = (
      user: 'alice',
      // Of the client and redirect URI it was issued to, checked as it is
      // redeemed, and of when the user signed in, not when it is redeemed.
      clientId: client.id,
      redirectUri: redirectUri,
      authTime: _signedInAt,
      scopes: scopes.toList(),
      openId: openId,
      pkce: req.container!.make<Pkce>(),
    );
    await res.redirect(
      completeAuthorizationCode(code, Uri.parse(redirectUri!), state: state),
    );
  }

  @override
  Future<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
    _Client? client,
    String? authCode,
    String? redirectUri,
    RequestContext req,
    ResponseContext res,
  ) async {
    // Used once, whatever comes of it; of the client it was issued to, and
    // of the same redirect URI, if it is given (RFC 6749 §4.1.3).
    var stored = _codes.remove(authCode);
    if (stored == null ||
        stored.clientId != client?.id ||
        (redirectUri != null && redirectUri != stored.redirectUri)) {
      throw AuthorizationException(
        ErrorResponse(ErrorResponse.invalidGrant, 'Unknown code.', ''),
      );
    }
    stored.pkce.validate(await getPkceCodeVerifier(req));
    var accessToken = 'at-${_next++}';
    _tokens[accessToken] = AccessToken(
      client: client,
      user: stored.user,
      scopes: stored.scopes,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    // Of the scopes granted, as the app may grant openid to a request of
    // no scope, which is not isOpenId.
    if (!stored.scopes.contains('openid')) {
      return AuthorizationTokenResponse(accessToken);
    }
    return IdTokenResponse(
      accessToken,
      expiresIn: 3600,
      idToken: issueIdToken(
        user: stored.user,
        client: client!,
        // Of its nonce, and of an auth_time that a max_age requires.
        request: stored.openId,
        authTime: stored.authTime,
        accessToken: accessToken,
      ),
    );
  }

  @override
  AccessToken<_Client, String>? findAccessToken(
    String token,
    RequestContext req,
  ) => _tokens[token];
}
