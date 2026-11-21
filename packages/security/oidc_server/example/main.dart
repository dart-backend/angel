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
    // Here, an app signs the user in and asks for their consent first.
    var code = 'code-${_next++}';
    _codes[code] = (
      user: 'alice',
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
    _Client? client,
    String? authCode,
    String? redirectUri,
    RequestContext req,
    ResponseContext res,
  ) async {
    var stored = _codes.remove(authCode);
    if (stored == null) {
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
    if (!stored.openId.isOpenId) return AuthorizationTokenResponse(accessToken);
    return IdTokenResponse(
      accessToken,
      expiresIn: 3600,
      idToken: issueIdToken(
        user: stored.user,
        client: client!,
        nonce: stored.openId.nonce,
        authTime: DateTime.now(),
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
