import 'dart:async';
import 'dart:convert';

import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_oidc_server/angel3_oidc_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

final _issuer = Uri.parse('https://id.example');
final _redirectUri = Uri.parse('https://app.example/cb');

/// A verifier of 43 `a`s, and its S256 challenge.
final _verifier = 'a' * 43;
const _challenge = 'ZtNPunH49FD35FWYhT5Tv8I7vRKQJ8uxMaL0_9eHjNA';

final _metadata = ServerMetadata(
  issuer: _issuer,
  authorizationEndpoint: _issuer.resolve('/oauth2/authorize'),
  tokenEndpoint: _issuer.resolve('/oauth2/token'),
  grantTypes: ['authorization_code', 'client_credentials'],
);

late OpenIdSigningKey _rsa;

void main() {
  late TestClient client;
  late _Provider provider;

  setUpAll(() => _rsa = OpenIdSigningKey.generate(keyId: 'rsa-1'));

  setUp(() async {
    provider = _Provider();
    var app = Angel();
    app.group('/oauth2', (router) {
      router
        ..get('/authorize', provider.authorizationEndpoint)
        ..post('/token', provider.tokenEndpoint)
        ..get('/jwks', provider.jwksEndpoint)
        ..get('/userinfo', provider.userInfoEndpoint)
        ..post('/userinfo', provider.userInfoEndpoint);
    });
    app.get(
      openIdConfigurationPath,
      provider.openIdConfigurationEndpoint(
        _metadata,
        jwksUri: _issuer.resolve('/oauth2/jwks'),
        userInfoEndpoint: _issuer.resolve('/oauth2/userinfo'),
      ),
    );
    app.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    client = await connectTo(app);
  });

  tearDown(() => client.close());

  /// The redirect of an authorization request of [query].
  Future<Uri> authorize(Map<String, String> query) async {
    var response = await client.get(
      Uri(
        path: '/oauth2/authorize',
        queryParameters: {
          'response_type': 'code',
          'client_id': 'app',
          'redirect_uri': '$_redirectUri',
          'state': 'st',
          'code_challenge': _challenge,
          'code_challenge_method': 'S256',
          ...query,
        },
      ),
    );
    expect(response.statusCode, 302, reason: response.body);
    return Uri.parse(response.headers['location']!);
  }

  /// The token response of the code of [redirect].
  Future<Map<String, dynamic>> exchange(Uri redirect) async {
    var response = await client.post(
      Uri.parse('/oauth2/token'),
      headers: {
        'authorization': 'Basic ${base64.encode(utf8.encode('app:secret'))}',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': redirect.queryParameters['code']!,
        'redirect_uri': '$_redirectUri',
        'code_verifier': _verifier,
      },
    );
    expect(response.statusCode, 200, reason: response.body);
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// The claims of [idToken], once it verifies of the provider's JWKS.
  Future<Map<String, dynamic>> verified(String idToken) async {
    var jwks = json.decode((await client.get(Uri.parse('/oauth2/jwks'))).body);
    var store = JsonWebKeyStore()
      ..addKeySet(JsonWebKeySet.fromJson(jwks as Map<String, dynamic>));
    var jws = JsonWebSignature.fromCompactSerialization(idToken);
    expect(await jws.verify(store), isTrue);
    return jws.unverifiedPayload.jsonContent as Map<String, dynamic>;
  }

  Future<http.Response> userInfo(String? token, {bool post = false}) {
    var headers = {
      if (token != null && !post) 'authorization': 'Bearer $token',
    };
    return post
        ? client.post(
            Uri.parse('/oauth2/userinfo'),
            headers: headers,
            body: {'access_token': ?token},
          )
        : client.get(Uri.parse('/oauth2/userinfo'), headers: headers);
  }

  group('a sign-in of the code flow', () {
    test('gives an ID token of the user, which verifies of the JWKS', () async {
      var redirect = await authorize({
        'scope': 'openid profile email',
        'nonce': 'n-123',
        'max_age': '300',
      });
      expect(redirect.queryParameters['state'], 'st');
      var tokens = await exchange(redirect);
      var claims = await verified(tokens['id_token'] as String);
      expect(claims['iss'], '$_issuer');
      expect(claims['sub'], 'user-1');
      expect(claims['aud'], 'app');
      expect(claims['nonce'], 'n-123');
      expect(
        claims['auth_time'],
        provider.authTime.millisecondsSinceEpoch ~/ 1000,
      );
      expect((claims['exp'] as int) - (claims['iat'] as int), 600);
      // The left half of the SHA-256 of the access token.
      var digest = sha256.convert(ascii.encode(tokens['access_token'])).bytes;
      expect(
        claims['at_hash'],
        base64Url.encode(digest.sublist(0, 16)).replaceAll('=', ''),
      );
      var header = json.decode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(tokens['id_token'].split('.')[0]),
          ),
        ),
      );
      expect(header['kid'], 'rsa-1');
      expect(header['alg'], 'RS256');
    });

    test('of no openid scope, gives no ID token', () async {
      var tokens = await exchange(await authorize({'scope': 'profile'}));
      expect(tokens, isNot(contains('id_token')));
    });

    test('of no nonce, gives an ID token of none', () async {
      var tokens = await exchange(await authorize({'scope': 'openid'}));
      var claims = await verified(tokens['id_token'] as String);
      expect(claims, isNot(contains('nonce')));
    });

    test(
      'of a malformed max_age or prompt redirects invalid_request',
      () async {
        for (var query in [
          {'scope': 'openid', 'max_age': 'soon'},
          {'scope': 'openid', 'prompt': 'none login'},
          {'scope': 'openid', 'prompt': 'maybe'},
        ]) {
          var redirect = await authorize(query);
          expect(
            redirect.queryParameters,
            containsPair('error', 'invalid_request'),
            reason: '$query',
          );
        }
      },
    );
  });

  group('UserInfo', () {
    late String token;

    setUp(() async {
      var tokens = await exchange(
        await authorize({'scope': 'openid profile email', 'nonce': 'n'}),
      );
      token = tokens['access_token'] as String;
    });

    test('gives the sub and the claims of the scopes of the token', () async {
      for (var post in [false, true]) {
        var response = await userInfo(token, post: post);
        expect(response.statusCode, 200, reason: response.body);
        expect(response.headers['cache-control'], 'no-store');
        expect(json.decode(response.body), {
          'sub': 'user-1',
          'name': 'Alice',
          'email': 'alice@example.com',
          'email_verified': true,
        });
      }
    });

    test(
      'refuses no token, a 401, and one of no openid scope, a 403',
      () async {
        expect((await userInfo(null)).statusCode, 401);
        var tokens = await exchange(await authorize({'scope': 'profile'}));
        var response = await userInfo(tokens['access_token'] as String);
        expect(response.statusCode, 403);
        expect(response.body, contains('insufficient_scope'));
      },
    );

    test('refuses a token of no user, as of client credentials', () async {
      var response = await client.post(
        Uri.parse('/oauth2/token'),
        headers: {
          'authorization': 'Basic ${base64.encode(utf8.encode('app:secret'))}',
        },
        body: {'grant_type': 'client_credentials', 'scope': 'openid'},
      );
      var machine = json.decode(response.body)['access_token'] as String;
      var info = await userInfo(machine);
      expect(info.statusCode, 401);
      expect(info.body, contains('invalid_token'));
    });
  });

  group('the configuration', () {
    test(
      'is of the issuer, its JWKS, UserInfo, and what OIDC requires',
      () async {
        var config = json.decode(
          (await client.get(Uri.parse(openIdConfigurationPath))).body,
        ) as Map;
        expect(config['issuer'], '$_issuer');
        expect(config['jwks_uri'], 'https://id.example/oauth2/jwks');
        expect(
          config['userinfo_endpoint'],
          'https://id.example/oauth2/userinfo',
        );
        expect(config['authorization_endpoint'], isNotNull);
        expect(config['token_endpoint'], isNotNull);
        expect(config['response_types_supported'], ['code']);
        expect(config['subject_types_supported'], ['public']);
        expect(config['id_token_signing_alg_values_supported'], ['RS256']);
        expect(config['scopes_supported'], containsAll(['openid', 'profile']));
        expect(config['claims_supported'], containsAll(['sub', 'email']));
      },
    );

    test('must be of the issuer of the server', () {
      expect(
        () => provider.openIdConfigurationOf(
          ServerMetadata(issuer: Uri.parse('https://other.example')),
          jwksUri: _issuer.resolve('/oauth2/jwks'),
        ),
        throwsArgumentError,
      );
    });
  });

  test('the JWKS is of the public keys alone, and may be cached', () async {
    var response = await client.get(Uri.parse('/oauth2/jwks'));
    expect(response.headers['cache-control'], 'public, max-age=3600');
    var keys = (json.decode(response.body) as Map)['keys'] as List;
    expect(keys.single, containsPair('kid', 'rsa-1'));
    expect(keys.single, isNot(contains('d')));
  });

  group('the server refuses', () {
    test('no RS256 key, which every provider must support', () {
      var ec = OpenIdSigningKey.generate(keyId: 'ec', algorithm: 'ES256');
      expect(() => _Provider(keys: [ec]), throwsArgumentError);
    });

    test('no key, or keys of the same id', () {
      expect(() => _Provider(keys: []), throwsArgumentError);
      expect(() => _Provider(keys: [_rsa, _rsa]), throwsArgumentError);
    });

    test('an issuer of http, but of localhost, or of a query', () {
      for (var issuer in ['http://id.example', 'https://id.example?a=b']) {
        expect(() => _Provider(issuer: Uri.parse(issuer)), throwsArgumentError);
      }
      _Provider(issuer: Uri.parse('http://localhost:3000'));
    });
  });
}

class _App {
  final String id, secret;
  const _App(this.id, this.secret);
}

class _User {
  final String id, name, email, phone;
  const _User(this.id, this.name, this.email, this.phone);
}

const _app = _App('app', 'secret');
const _alice = _User('user-1', 'Alice', 'alice@example.com', '+1 555 0100');

/// A code, as the provider stores it.
typedef _Code = ({
  _User user,
  List<String> scopes,
  OpenIdRequest openId,
  Pkce pkce,
});

/// A provider that signs Alice in at once.
class _Provider extends OpenIdServer<_App, _User> {
  _Provider({List<OpenIdSigningKey>? keys, Uri? issuer})
    : super(issuer: issuer ?? _issuer, signingKeys: keys ?? [_rsa]);

  final _codes = <String, _Code>{};
  final _tokens = <String, AccessToken<_App, _User>>{};
  final authTime = DateTime.now().subtract(const Duration(minutes: 1));
  var _next = 0;

  @override
  _App? findClient(String? clientId) => clientId == _app.id ? _app : null;

  @override
  bool verifyClient(_App client, String? clientSecret) =>
      client.secret == clientSecret;

  @override
  Uri? registeredRedirectUri(_App client, String? redirectUri) => _redirectUri;

  @override
  String clientIdOf(_App client) => client.id;

  @override
  String subjectOf(_User user) => user.id;

  @override
  Map<String, dynamic> claimsOf(_User user) => {
    'name': user.name,
    'email': user.email,
    'email_verified': true,
    'phone_number': user.phone,
    // Of no scope, so never given.
    'internal_id': 42,
  };

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
    var openId = req.container!.make<OpenIdRequest>();
    var code = 'code-${_next++}';
    _codes[code] = (
      user: _alice,
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
    _App? client,
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
    );
    if (!stored.scopes.contains('openid')) {
      return AuthorizationTokenResponse(accessToken, scope: stored.scopes);
    }
    return IdTokenResponse(
      accessToken,
      scope: stored.scopes,
      idToken: issueIdToken(
        user: stored.user,
        client: client!,
        nonce: stored.openId.nonce,
        authTime: authTime,
        accessToken: accessToken,
      ),
    );
  }

  @override
  Future<AuthorizationTokenResponse> clientCredentialsGrant(
    _App? client,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) async {
    var accessToken = 'machine-${_next++}';
    _tokens[accessToken] = AccessToken(client: client, scopes: scopes);
    return AuthorizationTokenResponse(accessToken);
  }

  @override
  AccessToken<_App, _User>? findAccessToken(String token, RequestContext req) =>
      _tokens[token];
}
