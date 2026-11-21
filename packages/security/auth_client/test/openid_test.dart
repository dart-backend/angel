import 'dart:async';
import 'dart:convert';
import 'dart:io' show Cookie;

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_auth_client/angel3_auth_client.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:angel3_oidc_server/angel3_oidc_server.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

final _issuer = Uri.parse('https://id.example');
final _jwksUri = _issuer.resolve('/jwks');

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

String _halfHash(String value) {
  var digest = sha256.convert(ascii.encode(value)).bytes;
  return _b64(digest.sublist(0, 16));
}

void main() {
  late OpenIdSigningKey key, other;

  setUpAll(() {
    key = OpenIdSigningKey.generate(keyId: 'k1');
    other = OpenIdSigningKey.generate(keyId: 'k2');
  });

  // The provider: its keys, of the JSON Web Key Set; how it makes the ID
  // token of the nonce of a login, of `null` for none; and what it was asked.
  late List<OpenIdSigningKey> published;
  late String? Function(String nonce, String accessToken) idTokenOf;
  late int jwksFetches;
  late bool jwksDown;
  late List<String> errors;
  late AngelHttp http_;

  /// The claims of an ID token of [nonce], as the provider gives them.
  Map<String, dynamic> claimsOf(String nonce, {String accessToken = 'at'}) {
    var now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return {
      'iss': '$_issuer',
      'sub': 'alice',
      'aud': 'app',
      'iat': now,
      'exp': now + 600,
      'nonce': nonce,
      'at_hash': _halfHash(accessToken),
    };
  }

  setUp(() async {
    published = [key];
    idTokenOf = (nonce, at) => key.signJwt(claimsOf(nonce, accessToken: at));
    jwksFetches = 0;
    jwksDown = false;
    errors = [];
    var nonces = <String>[];

    var provider = MockClient((request) async {
      if (request.url == _jwksUri) {
        jwksFetches++;
        if (jwksDown) throw http.ClientException('down', request.url);
        return http.Response(
          json.encode({
            'keys': [for (var k in published) k.publicJwk],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      var idToken = idTokenOf(nonces.last, 'at');
      return http.Response(
        json.encode({
          'access_token': 'at',
          'token_type': 'bearer',
          'id_token': ?idToken,
        }),
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
    auth.strategies['oidc'] = OAuth2Strategy<String>(
      ExternalAuthOptions(
        clientId: 'app',
        clientSecret: 'secret',
        redirectUri: 'https://app.example/auth/callback',
        scopes: ['openid', 'email'],
      ),
      _issuer.resolve('/authorize'),
      _issuer.resolve('/token'),
      (client, req, res) => req.container!.make<IdToken>().subject,
      (e, req, res) {
        errors.add(e.error);
        res.statusCode = 400;
        return {'error': e.error, 'description': e.description};
      },
      httpClient: provider,
      openId: OpenIdOptions(issuer: _issuer, jwksUri: _jwksUri),
    );
    await app.configure(auth.configureServer);
    app
      ..get('/auth/start', (req, res) async {
        var result = await auth.authenticate('oidc')(req, res);
        // The nonce of the login, as the provider is sent it.
        var location = res.headers['location'];
        if (location != null) {
          nonces.add(Uri.parse(location).queryParameters['nonce'] ?? '');
        }
        return result;
      })
      ..get('/auth/callback', auth.authenticate('oidc'));
    http_ = AngelHttp(app);
  });

  /// A login, to its callback: the status and body of the callback.
  Future<(int, Map)> login() async {
    var start = MockHttpRequest('GET', Uri.parse('/auth/start'));
    await start.close();
    await http_.handleRequest(start);
    var url = Uri.parse(start.response.headers.value('location')!);
    var cookie = start.response.cookies.singleWhere(
      (c) => c.name.startsWith('angel3_oauth2_'),
    );
    var cb = MockHttpRequest(
      'GET',
      Uri(
        path: '/auth/callback',
        queryParameters: {'code': 'c', 'state': url.queryParameters['state']},
      ),
    )..headers.add('accept', 'application/json');
    cb.cookies.add(Cookie(cookie.name, cookie.value));
    await cb.close();
    await http_.handleRequest(cb);
    var body = await cb.response.transform(utf8.decoder).join();
    return (cb.response.statusCode, json.decode(body) as Map);
  }

  Future<void> expectRefused(String reason) async {
    var (status, body) = await login();
    expect(status, 400, reason: '$body');
    expect(body['error'], 'invalid_token');
    expect(body['description'], contains(reason));
  }

  test('a login of a valid ID token gives the verifier the IdToken', () async {
    var (status, body) = await login();
    expect(status, 200, reason: '$body');
    expect(body['data'], 'alice');
    expect(errors, isEmpty);
  });

  test('each login sends a nonce of its own', () async {
    var urls = <Uri>[];
    for (var i = 0; i < 2; i++) {
      var rq = MockHttpRequest('GET', Uri.parse('/auth/start'));
      await rq.close();
      await http_.handleRequest(rq);
      urls.add(Uri.parse(rq.response.headers.value('location')!));
    }
    var nonces = [for (var url in urls) url.queryParameters['nonce']];
    expect(nonces[0], hasLength(32));
    expect(nonces[0], isNot(nonces[1]));
    expect(urls[0].queryParameters['scope'], 'openid email');
  });

  group('an ID token is refused', () {
    test('of another issuer', () async {
      idTokenOf = (n, at) =>
          key.signJwt({...claimsOf(n), 'iss': 'https://evil.example'});
      await expectRefused('issuer');
    });

    test('of another audience', () async {
      idTokenOf = (n, at) => key.signJwt({...claimsOf(n), 'aud': 'other'});
      await expectRefused('audience');
    });

    test('of several audiences, of no azp of this app', () async {
      idTokenOf = (n, at) => key.signJwt({
        ...claimsOf(n),
        'aud': ['app', 'other'],
      });
      await expectRefused('issued to');
      idTokenOf = (n, at) => key.signJwt({
        ...claimsOf(n),
        'aud': ['app', 'other'],
        'azp': 'other',
      });
      await expectRefused('issued to');
    });

    test('that has expired, beyond the clock skew', () async {
      var now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      idTokenOf = (n, at) =>
          key.signJwt({...claimsOf(n), 'iat': now - 900, 'exp': now - 300});
      await expectRefused('expired');
    });

    test('that was issued ahead of now, beyond the clock skew', () async {
      var now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      idTokenOf = (n, at) =>
          key.signJwt({...claimsOf(n), 'iat': now + 600, 'exp': now + 1200});
      await expectRefused('ahead');
    });

    test('of another nonce, as of a replay', () async {
      idTokenOf = (n, at) => key.signJwt(claimsOf('another nonce'));
      await expectRefused('nonce');
    });

    test('of no sub', () async {
      idTokenOf = (n, at) => key.signJwt({...claimsOf(n)}..remove('sub'));
      await expectRefused('sub');
    });

    test('of an at_hash of another access token', () async {
      idTokenOf = (n, at) => key.signJwt(claimsOf(n, accessToken: 'other'));
      await expectRefused('at_hash');
    });

    test('of a key that is not the provider\'s', () async {
      idTokenOf = (n, at) => other.signJwt(claimsOf(n));
      await expectRefused('signature');
    });

    test('of alg none', () async {
      idTokenOf = (n, at) =>
          '${_b64(utf8.encode('{"alg":"none"}'))}.'
          '${_b64(utf8.encode(json.encode(claimsOf(n))))}.';
      await expectRefused('algorithm');
    });

    test(
      'of HS256, of the client secret, which the client could forge',
      () async {
        idTokenOf = (n, at) {
          var input =
              '${_b64(utf8.encode('{"alg":"HS256","kid":"k1"}'))}.'
              '${_b64(utf8.encode(json.encode(claimsOf(n))))}';
          var mac = Hmac(
            sha256,
            utf8.encode('secret'),
          ).convert(ascii.encode(input));
          return '$input.${_b64(mac.bytes)}';
        };
        await expectRefused('algorithm');
      },
    );

    test('that is not a JWS', () async {
      idTokenOf = (n, at) => 'not.a.token';
      await expectRefused('');
    });

    test('of none at all', () async {
      idTokenOf = (n, at) => null;
      await expectRefused('no ID token');
    });
  });

  test('a token of a new key of the provider fetches its keys again, but of '
      'unknown keys at most once a minute', () async {
    expect((await login()).$1, 200);
    expect(jwksFetches, 1);
    // The provider rotates to k2.
    published = [other, key];
    idTokenOf = (n, at) => other.signJwt(claimsOf(n));
    expect((await login()).$1, 200);
    expect(jwksFetches, 2);
    // A token of a key no one has: refused, of no fetch again so soon.
    var stranger = OpenIdSigningKey.generate(keyId: 'k3', algorithm: 'ES256');
    idTokenOf = (n, at) => stranger.signJwt(claimsOf(n));
    await expectRefused('signature');
    expect(jwksFetches, 2);
  });

  test('keys that cannot be fetched are a 502', () async {
    jwksDown = true;
    var (status, _) = await login();
    expect(status, 502);
  });

  test('a JWKS that is not an object is a 502, not a 500', () async {
    published = [];
    var verifier = IdTokenVerifier(
      OpenIdOptions(issuer: _issuer, jwksUri: _jwksUri),
      MockClient((request) async => http.Response('[]', 200)),
      timeout: const Duration(seconds: 5),
    );
    await expectLater(
      verifier.verify(key.signJwt(claimsOf('n')), clientId: 'app', nonce: 'n'),
      throwsA(isA<http.ClientException>()),
    );
  });

  group('the keys', () {
    /// A verifier of a provider of [key], of [fetches] counted, which fails
    /// once [down], and answers in [delay].
    late int fetches;
    late bool down;

    IdTokenVerifier verifierOf({
      Duration keysLifetime = const Duration(hours: 1),
      Duration delay = Duration.zero,
    }) {
      fetches = 0;
      down = false;
      return IdTokenVerifier(
        OpenIdOptions(
          issuer: _issuer,
          jwksUri: _jwksUri,
          keysLifetime: keysLifetime,
        ),
        MockClient((request) async {
          fetches++;
          await Future<void>.delayed(delay);
          if (down) throw http.ClientException('down', request.url);
          return http.Response(
            json.encode({
              'keys': [key.publicJwk],
            }),
            200,
          );
        }),
        timeout: const Duration(seconds: 5),
      );
    }

    test('of a refresh that fails, are those fetched before', () async {
      var verifier = verifierOf(keysLifetime: Duration.zero);
      await verifier.verify(
        key.signJwt(claimsOf('n')),
        clientId: 'app',
        nonce: 'n',
      );
      down = true;
      var idToken = await verifier.verify(
        key.signJwt(claimsOf('n')),
        clientId: 'app',
        nonce: 'n',
      );
      expect(idToken.subject, 'alice');
      expect(fetches, 2);
    });

    test('are fetched once, of logins at once', () async {
      var verifier = verifierOf(delay: const Duration(milliseconds: 20));
      await Future.wait([
        for (var i = 0; i < 5; i++)
          verifier.verify(
            key.signJwt(claimsOf('n')),
            clientId: 'app',
            nonce: 'n',
          ),
      ]);
      expect(fetches, 1);
    });

    test(
      'an access token that is not ASCII is refused, of an at_hash',
      () async {
        var verifier = verifierOf();
        await expectLater(
          verifier.verify(
            key.signJwt(claimsOf('n')),
            clientId: 'app',
            nonce: 'n',
            accessToken: 'tökén',
          ),
          throwsA(isA<IdTokenException>()),
        );
      },
    );
  });

  group('the options refuse', () {
    test('a strategy of no openid scope', () {
      expect(
        () => OAuth2Strategy<String>(
          ExternalAuthOptions(
            clientId: 'app',
            clientSecret: 'secret',
            redirectUri: 'https://app.example/cb',
            scopes: ['email'],
          ),
          _issuer.resolve('/authorize'),
          _issuer.resolve('/token'),
          (client, req, res) => 'alice',
          (e, req, res) => null,
          openId: OpenIdOptions(issuer: _issuer, jwksUri: _jwksUri),
        ),
        throwsArgumentError,
      );
    });

    test('an issuer of http, but of localhost', () {
      expect(
        () => OpenIdOptions(
          issuer: Uri.parse('http://id.example'),
          jwksUri: _jwksUri,
        ),
        throwsArgumentError,
      );
      OpenIdOptions(
        issuer: Uri.parse('http://localhost:3000'),
        jwksUri: _jwksUri,
      );
    });

    test('a JWKS of http, but of localhost', () {
      expect(
        () => OpenIdOptions(
          issuer: _issuer,
          jwksUri: Uri.parse('http://id.example/jwks'),
        ),
        throwsArgumentError,
      );
    });

    test('an algorithm of a shared secret, or none', () {
      for (var alg in ['HS256', 'none']) {
        expect(
          () => OpenIdOptions(
            issuer: _issuer,
            jwksUri: _jwksUri,
            algorithms: {alg},
          ),
          throwsArgumentError,
        );
      }
    });
  });

  test('a nonce of authorizationParameters is dropped, of the strategy\'s', () {
    var warnings = <String>[];
    var sub = Logger.root.onRecord.listen((r) => warnings.add(r.message));
    addTearDown(sub.cancel);
    OAuth2Strategy<String>(
      ExternalAuthOptions(
        clientId: 'app',
        clientSecret: 'secret',
        redirectUri: 'https://app.example/cb',
        scopes: ['openid'],
      ),
      _issuer.resolve('/authorize'),
      _issuer.resolve('/token'),
      (client, req, res) => 'alice',
      (e, req, res) => null,
      authorizationParameters: {'nonce': 'fixed'},
      openId: OpenIdOptions(issuer: _issuer, jwksUri: _jwksUri),
    );
    expect(warnings, contains(contains('nonce')));
  });

  group('discover', () {
    http.Client configured(Object config, {String path = '/'}) =>
        MockClient((request) async {
          expect(
            request.url.path,
            '${path == '/' ? '' : path}/.well-known/openid-configuration',
          );
          return http.Response(json.encode(config), 200);
        });

    test('reads the endpoints and keys of the provider', () async {
      var provider = await OpenIdOptions.discover(
        _issuer,
        httpClient: configured({
          'issuer': '$_issuer',
          'authorization_endpoint': 'https://id.example/authorize',
          'token_endpoint': 'https://id.example/token',
          'jwks_uri': 'https://id.example/jwks',
          'userinfo_endpoint': 'https://id.example/userinfo',
          'end_session_endpoint': 'https://id.example/logout',
          'id_token_signing_alg_values_supported': ['RS256', 'HS256'],
        }),
      );
      expect(
        provider.endSessionUrl(
          idTokenHint: 'h',
          postLogoutRedirectUri: Uri.parse('https://app.example/out'),
          state: 's',
        ),
        Uri.parse(
          'https://id.example/logout?id_token_hint=h&post_logout_redirect_uri='
          'https%3A%2F%2Fapp.example%2Fout&state=s',
        ),
      );
      expect(provider.authorizationEndpoint.path, '/authorize');
      expect(provider.tokenEndpoint.path, '/token');
      expect(provider.userInfoEndpoint?.path, '/userinfo');
      expect(provider.openId.jwksUri, _jwksUri);
      // Of no HS256, which is not of a public key.
      expect(provider.openId.algorithms, {'RS256'});
    });

    test('of an issuer of a path, at its path', () async {
      var issuer = Uri.parse('https://id.example/tenant');
      var provider = await OpenIdOptions.discover(
        issuer,
        httpClient: configured({
          'issuer': '$issuer',
          'authorization_endpoint': 'https://id.example/tenant/authorize',
          'token_endpoint': 'https://id.example/tenant/token',
          'jwks_uri': 'https://id.example/tenant/jwks',
        }, path: '/tenant'),
      );
      expect(provider.openId.issuer, issuer);
      // Of no end session endpoint.
      expect(provider.endSessionEndpoint, isNull);
      expect(() => provider.endSessionUrl(), throwsStateError);
    });

    test('refuses a configuration of another issuer', () async {
      expect(
        OpenIdOptions.discover(
          _issuer,
          httpClient: configured({
            'issuer': 'https://evil.example',
            'authorization_endpoint': 'https://evil.example/authorize',
            'token_endpoint': 'https://evil.example/token',
            'jwks_uri': 'https://evil.example/jwks',
          }),
        ),
        throwsFormatException,
      );
    });

    test('refuses a configuration of a JWKS of http', () async {
      expect(
        OpenIdOptions.discover(
          _issuer,
          httpClient: configured({
            'issuer': '$_issuer',
            'authorization_endpoint': 'https://id.example/authorize',
            'token_endpoint': 'https://id.example/token',
            'jwks_uri': 'http://id.example/jwks',
          }),
        ),
        throwsFormatException,
      );
    });

    test('times out of a provider that does not answer', () async {
      expect(
        OpenIdOptions.discover(
          _issuer,
          httpClient: MockClient(
            (request) => Completer<http.Response>().future,
          ),
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('refuses a configuration of no JWKS', () async {
      expect(
        OpenIdOptions.discover(
          _issuer,
          httpClient: configured({
            'issuer': '$_issuer',
            'authorization_endpoint': 'https://id.example/authorize',
            'token_endpoint': 'https://id.example/token',
          }),
        ),
        throwsFormatException,
      );
    });
  });
}
