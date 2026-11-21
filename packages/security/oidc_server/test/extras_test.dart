import 'dart:convert';

import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_oidc_server/angel3_oidc_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

final _issuer = Uri.parse('https://id.example');
final _redirectUri = Uri.parse('https://app.example/cb');
final _postLogout = Uri.parse('https://app.example/signed-out');
const _challenge = 'ZtNPunH49FD35FWYhT5Tv8I7vRKQJ8uxMaL0_9eHjNA';

final _metadata = ServerMetadata(
  issuer: _issuer,
  authorizationEndpoint: _issuer.resolve('/oauth2/authorize'),
  tokenEndpoint: _issuer.resolve('/oauth2/token'),
  registrationEndpoint: _issuer.resolve('/oauth2/register'),
  clientAuthMethods: ['client_secret_basic', 'none'],
);

late OpenIdSigningKey _rsa, _ec;

Map<String, dynamic> _headerOf(String jwt) => json.decode(
  utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[0]))),
);

void main() {
  setUpAll(() {
    _rsa = OpenIdSigningKey.generate(keyId: 'rsa');
    _ec = OpenIdSigningKey.generate(keyId: 'ec', algorithm: 'ES256');
  });

  group('interactions', () {
    OpenIdRequest request({Set<String> prompt = const {}, int? maxAge}) =>
        OpenIdRequest(
          isOpenId: true,
          prompt: prompt,
          maxAge: maxAge,
          state: 'st',
        );
    var now = DateTime(2026, 11, 21, 12);
    var recently = now.subtract(const Duration(minutes: 1));

    test('are none of a user signed in recently, who consented', () {
      expect(
        request().interactions(signedIn: true, authTime: recently, now: now),
        isEmpty,
      );
    });

    test('are a login of a user who is not signed in, or not recently', () {
      expect(request().interactions(signedIn: false), {
        OpenIdInteraction.login,
      });
      expect(
        request(maxAge: 30)
            .interactions(signedIn: true, authTime: recently, now: now),
        {OpenIdInteraction.login},
      );
      // Of no authTime, of a max_age: when is not known.
      expect(request(maxAge: 3600).interactions(signedIn: true, now: now), {
        OpenIdInteraction.login,
      });
      // Of the client's default_max_age, of a request of none.
      expect(
        request().interactions(
          signedIn: true,
          authTime: recently,
          defaultMaxAge: 30,
          now: now,
        ),
        {OpenIdInteraction.login},
      );
    });

    test('of prompt are always asked, of the request as it first came', () {
      var old = now.subtract(const Duration(days: 1));
      for (var (r, asked) in [
        (request(prompt: {'login'}), {OpenIdInteraction.login}),
        (request(maxAge: 0), {OpenIdInteraction.login}),
        (request(prompt: {'consent'}), {OpenIdInteraction.consent}),
        (
          request(prompt: {'select_account'}),
          {OpenIdInteraction.selectAccount},
        ),
        (
          request(prompt: {'login', 'consent'}),
          {OpenIdInteraction.login, OpenIdInteraction.consent},
        ),
      ]) {
        // Exactly what was asked, nothing more.
        expect(
          r.interactions(signedIn: true, authTime: now, now: now),
          asked,
          reason: '${r.prompt} ${r.maxAge}',
        );
      }
      // Of a user not signed in, a login, whatever the prompt.
      expect(
        request(prompt: {'consent'}).interactions(signedIn: false, now: now),
        {OpenIdInteraction.login, OpenIdInteraction.consent},
      );
      expect(
        request().interactions(
          signedIn: true,
          authTime: now,
          consented: false,
          now: now,
        ),
        {OpenIdInteraction.consent},
      );
      expect(
        request(maxAge: 60)
            .interactions(signedIn: true, authTime: old, now: now),
        {OpenIdInteraction.login},
      );
      // Of the exact time, not of whole seconds.
      expect(
        request(maxAge: 60).interactions(
          signedIn: true,
          authTime: now.subtract(const Duration(milliseconds: 60900)),
          now: now,
        ),
        {OpenIdInteraction.login},
      );
    });

    test('of a default_max_age of no Duration, overflow not', () {
      // 2^62 seconds overflow a Duration's microseconds.
      expect(
        request().interactions(
          signedIn: true,
          authTime: recently,
          defaultMaxAge: 1 << 62,
          now: now,
        ),
        isEmpty,
      );
    });

    test('of a max_age of no Duration, overflow not', () {
      var r = OpenIdRequest.of({
        'scope': 'openid',
        'max_age': '10000000000000',
      }, 'st');
      expect(
        r.interactions(signedIn: true, authTime: recently, now: now),
        isEmpty,
      );
    });

    test('of max_age=0 are a login, whenever the user authenticated', () {
      expect(
        request(maxAge: 0)
            .interactions(signedIn: true, authTime: now, now: now),
        {OpenIdInteraction.login},
      );
    });

    test('are what prompt asks for, and consent the user has not given', () {
      expect(
        request(prompt: {'login', 'select_account', 'consent'})
            .interactions(signedIn: true, authTime: recently, now: now),
        {
          OpenIdInteraction.login,
          OpenIdInteraction.selectAccount,
          OpenIdInteraction.consent,
        },
      );
      expect(
        request().interactions(
          signedIn: true,
          authTime: recently,
          consented: false,
          now: now,
        ),
        {OpenIdInteraction.consent},
      );
    });

    test('of prompt=none, throw what the user would have had to do', () {
      Matcher errorOf(String code) => throwsA(
        isA<AuthorizationException>()
            .having((e) => e.errorResponse.code, 'code', code)
            .having((e) => e.errorResponse.state, 'state', 'st'),
      );
      expect(
        () => request(prompt: {'none'}).interactions(signedIn: false),
        errorOf(OpenIdErrors.loginRequired),
      );
      expect(
        () => request(prompt: {'none'}).interactions(
          signedIn: true,
          authTime: recently,
          consented: false,
          now: now,
        ),
        errorOf(OpenIdErrors.consentRequired),
      );
      expect(
        request(prompt: {'none'})
            .interactions(signedIn: true, authTime: recently, now: now),
        isEmpty,
      );
    });
  });

  group('the OpenID Connect parameters', () {
    test('of a max_age of no digits alone are refused', () {
      for (var value in ['0x10', '+5', '-1', '1.5', '']) {
        expect(
          () => OpenIdRequest.of({'scope': 'openid', 'max_age': value}, 's'),
          throwsA(isA<AuthorizationException>()),
          reason: value,
        );
      }
    });

    test('of a max_age above maxMaxAge, capped at it', () {
      var r = OpenIdRequest.of({
        'scope': 'openid',
        'max_age': '99999999999999999999',
      }, 's');
      // Capped, so that an app's Duration of it does not overflow.
      expect(r.maxAge, OpenIdRequest.maxMaxAge);
      expect(
        OpenIdRequest.of({
          'scope': 'openid',
          'max_age': '9999999999999',
        }, 's').maxAge,
        OpenIdRequest.maxMaxAge,
      );
      expect(
        r.interactions(
          signedIn: true,
          authTime: DateTime(2000),
          now: DateTime(2026),
        ),
        isEmpty,
      );
    });

    test('of a blank scope are checked, as of none', () {
      expect(
        () => OpenIdRequest.of({'scope': '  ', 'prompt': 'bogus'}, 's'),
        throwsA(isA<AuthorizationException>()),
      );
    });

    test('of prompt are of any whitespace', () {
      var r = OpenIdRequest.of({
        'scope': 'openid',
        'prompt': 'login\tconsent',
      }, 's');
      expect(r.prompt, {'login', 'consent'});
    });

    test('of a request of no scope at all are checked, as the app may grant '
        'openid by default', () {
      expect(
        () => OpenIdRequest.of({'prompt': 'bogus'}, 's'),
        throwsA(isA<AuthorizationException>()),
      );
      var r = OpenIdRequest.of({'prompt': 'none', 'nonce': 'n'}, 's');
      expect(r.isOpenId, isFalse);
      expect(r.prompt, {'none'});
      expect(r.nonce, 'n');
    });

    test('of an OAuth2 request, of no openid scope, are not checked', () {
      var r = OpenIdRequest.of({
        'scope': 'profile',
        'prompt': 'bogus',
        'max_age': 'soon',
      }, 's');
      expect(r.isOpenId, isFalse);
      expect(r.prompt, isEmpty);
    });
  });

  group('of a provider', () {
    late TestClient client;
    late _Provider provider;

    setUp(() async {
      provider = _Provider();
      var app = Angel();
      app.group('/oauth2', (router) {
        router
          ..get('/authorize', provider.authorizationEndpoint)
          ..post('/register', provider.registrationEndpoint(_metadata))
          ..get('/logout', provider.endSessionEndpoint)
          ..post('/logout', provider.endSessionEndpoint);
      });
      app.get(
        openIdConfigurationPath,
        provider.openIdConfigurationEndpoint(
          _metadata,
          jwksUri: _issuer.resolve('/oauth2/jwks'),
          endSessionEndpoint: _issuer.resolve('/oauth2/logout'),
        ),
      );
      app.errorHandler = (e, req, res) async {
        res.statusCode = e.statusCode;
        res.json(e.toJson());
      };
      client = await connectTo(app);
    });

    tearDown(() => client.close());

    test('a malformed prompt is refused, of an app that never reads the '
        'OpenIdRequest', () async {
      var plain = _Plain();
      var app = Angel()..get('/authorize', plain.authorizationEndpoint);
      app.errorHandler = (e, req, res) async {
        res.statusCode = e.statusCode;
        res.json(e.toJson());
      };
      var other = await connectTo(app);
      var response = await other.get(
        Uri(
          path: '/authorize',
          queryParameters: {
            'response_type': 'code',
            'client_id': 'app',
            'redirect_uri': '$_redirectUri',
            'scope': 'openid',
            'prompt': 'bogus',
            'code_challenge': _challenge,
            'code_challenge_method': 'S256',
          },
        ),
      );
      await other.close();
      expect(response.statusCode, 400);
      expect(response.body, contains('invalid_request'));
      expect(response.body, contains('prompt'));
    });

    test('prompt=none of a user who is not signed in redirects '
        'login_required', () async {
      var response = await client.get(
        Uri(
          path: '/oauth2/authorize',
          queryParameters: {
            'response_type': 'code',
            'client_id': 'app',
            'scope': 'openid',
            'state': 'st',
            'prompt': 'none',
            'code_challenge': _challenge,
            'code_challenge_method': 'S256',
          },
        ),
      );
      expect(response.statusCode, 302);
      var location = Uri.parse(response.headers['location']!);
      expect(location.queryParameters, {
        'error': 'login_required',
        'error_description': 'The user must sign in.',
        'state': 'st',
      });
    });

    group('registration', () {
      Future<http.Response> register(Map<String, dynamic> body) => client.post(
        Uri.parse('/oauth2/register'),
        headers: {'content-type': 'application/json'},
        body: json.encode({
          'redirect_uris': ['$_redirectUri'],
          ...body,
        }),
      );

      void expectRefused(http.Response response, String error) {
        expect(response.statusCode, 400, reason: response.body);
        expect(json.decode(response.body), containsPair('error', error));
      }

      test('gives the OpenID Connect metadata of its defaults', () async {
        var response = await register({
          'post_logout_redirect_uris': ['$_postLogout'],
          'default_max_age': 3600,
        });
        expect(response.statusCode, 201, reason: response.body);
        var json_ = json.decode(response.body) as Map;
        expect(json_, containsPair('id_token_signed_response_alg', 'RS256'));
        expect(json_, containsPair('subject_type', 'public'));
        expect(json_, containsPair('application_type', 'web'));
        expect(json_, containsPair('require_auth_time', false));
        var stored = OpenIdClientMetadata.of(
          provider.registered.single.metadata,
        );
        expect(stored.postLogoutRedirectUris, [_postLogout]);
        expect(stored.defaultMaxAge, 3600);
        // Capped at maxMaxAge, as a request's max_age.
        var big = await register({'default_max_age': 1 << 40});
        expect(big.statusCode, 201, reason: big.body);
        expect(
          OpenIdClientMetadata.of(provider.registered.last.metadata)
              .defaultMaxAge,
          OpenIdRequest.maxMaxAge,
        );
      });

      test('of the openid scope, of metadata of scopes of none', () async {
        var app = Angel()
          ..post(
            '/register',
            provider.registrationEndpoint(
              _metadata.copyWith(scopes: ['profile']),
            ),
          );
        app.errorHandler = (e, req, res) async {
          res.statusCode = e.statusCode;
          res.json(e.toJson());
        };
        var other = await connectTo(app);
        var response = await other.post(
          Uri.parse('/register'),
          headers: {'content-type': 'application/json'},
          body: json.encode({
            'redirect_uris': ['$_redirectUri'],
            'scope': 'openid profile',
          }),
        );
        await other.close();
        expect(response.statusCode, 201, reason: response.body);
      });

      test('of an algorithm of a key of the provider', () async {
        var response = await register({
          'id_token_signed_response_alg': 'ES256',
        });
        expect(response.statusCode, 201, reason: response.body);
        expectRefused(
          await register({'id_token_signed_response_alg': 'HS256'}),
          'invalid_client_metadata',
        );
      });

      test('refuses metadata that is not valid, or not supported', () async {
        for (var body in [
          {'subject_type': 'pairwise'},
          {'default_max_age': -1},
          {'require_auth_time': 'yes'},
          {'application_type': 'desktop'},
          {'userinfo_signed_response_alg': 'RS256'},
          {
            'request_uris': ['https://app.example/r'],
          },
          {'initiate_login_uri': 'http://app.example/login'},
          {'initiate_login_uri': 'https:/no-host'},
        ]) {
          expectRefused(await register(body), 'invalid_client_metadata');
        }
        expectRefused(
          await register({
            'post_logout_redirect_uris': ['javascript:alert(1)'],
          }),
          'invalid_redirect_uri',
        );
        expect(provider.registered, isEmpty);
      });
    });

    test('an ID token of a client of no algorithm is of RS256, of an ES256 '
        'key first', () {
      var plain = _Plain(keys: [_ec, _rsa]);
      var token = plain.issueIdToken(user: 'alice', client: 'app');
      expect(_headerOf(token), containsPair('alg', 'RS256'));
    });

    test('the claims given to an ID token never set its own', () {
      var token = provider.issueIdToken(
        user: 'alice',
        client: 'app',
        claims: {
          'nonce': 'stale',
          'auth_time': 'x',
          'sub': 'mallory',
          'acr': '1',
        },
      );
      var claims = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map;
      expect(claims, isNot(contains('nonce')));
      expect(claims, isNot(contains('auth_time')));
      expect(claims['sub'], 'alice');
      expect(claims['acr'], '1');
    });

    test('an ID token is of the request and client metadata given', () {
      var token = provider.issueIdToken(
        user: 'alice',
        client: 'app',
        request: OpenIdRequest(isOpenId: true, nonce: 'n-1', maxAge: 60),
        authTime: DateTime.now(),
        clientMetadata: OpenIdClientMetadata(idTokenSignedResponseAlg: 'ES256'),
      );
      expect(_headerOf(token)['alg'], 'ES256');
      var claims = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map;
      expect(claims['nonce'], 'n-1');
      // Of a max_age, or a client of require_auth_time or default_max_age:
      // of no authTime, refused.
      for (var (request, metadata) in [
        (OpenIdRequest(isOpenId: true, maxAge: 60), null),
        (null, OpenIdClientMetadata(requireAuthTime: true)),
        (null, OpenIdClientMetadata(defaultMaxAge: 60)),
      ]) {
        expect(
          () => provider.issueIdToken(
            user: 'alice',
            client: 'app',
            request: request,
            clientMetadata: metadata,
          ),
          throwsArgumentError,
        );
      }
    });

    test(
      'the algorithm of idTokenAlgorithmOf comes before the metadata\'s',
      () {
        var token = provider.issueIdToken(
          user: 'alice',
          client: 'es-app',
          clientMetadata: OpenIdClientMetadata(),
        );
        expect(_headerOf(token)['alg'], 'ES256');
      },
    );

    test('an ID token of a request of no openid scope is an ArgumentError, '
        'but of one of no scope, which may be granted it', () {
      expect(
        () => provider.issueIdToken(
          user: 'alice',
          client: 'app',
          request: OpenIdRequest(isOpenId: false),
        ),
        throwsArgumentError,
      );
      var scopeless = OpenIdRequest.of({'nonce': 'n'}, 's');
      expect(scopeless.hasScope, isFalse);
      var token = provider.issueIdToken(
        user: 'alice',
        client: 'app',
        request: scopeless,
      );
      var claims = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map;
      expect(claims['nonce'], 'n');
    });

    test('an access token that is not ASCII is an ArgumentError', () {
      expect(
        () => provider.issueIdToken(
          user: 'alice',
          client: 'app',
          accessToken: 'tökén',
        ),
        throwsArgumentError,
      );
    });

    test('an override of a hook, of a plain return type, reads the '
        'OpenIdRequest of super, not awaited', () async {
      var sync = _Sync();
      var app = Angel()..get('/authorize', sync.authorizationEndpoint);
      app.errorHandler = (e, req, res) async {
        res.statusCode = e.statusCode;
        res.json(e.toJson());
      };
      var other = await connectTo(app);
      var response = await other.get(
        Uri(
          path: '/authorize',
          queryParameters: {
            'response_type': 'code',
            'client_id': 'app',
            'redirect_uri': '$_redirectUri',
            'scope': 'openid',
            'code_challenge': _challenge,
            'code_challenge_method': 'S256',
          },
        ),
      );
      await other.close();
      // Past the hook, to requestAuthorizationCode's default refusal.
      expect(response.body, contains('unsupported_response_type'));
    });

    test('each request is checked, of an OpenIdRequest registered on the '
        'app', () async {
      var sync = _Sync();
      var app = Angel()..get('/authorize', sync.authorizationEndpoint);
      app.container.registerSingleton(OpenIdRequest(isOpenId: true));
      app.errorHandler = (e, req, res) async {
        res.statusCode = e.statusCode;
        res.json(e.toJson());
      };
      var other = await connectTo(app);
      var response = await other.get(
        Uri(
          path: '/authorize',
          queryParameters: {
            'response_type': 'code',
            'client_id': 'app',
            'redirect_uri': '$_redirectUri',
            'scope': 'openid',
            'prompt': 'bogus',
            'code_challenge': _challenge,
            'code_challenge_method': 'S256',
          },
        ),
      );
      await other.close();
      expect(response.statusCode, 400);
      expect(response.body, contains('prompt'));
    });

    test('the signing keys cannot be changed', () {
      expect(() => provider.signingKeys.add(_rsa), throwsUnsupportedError);
    });

    test('the metadata of RFC 8414 lists openid, of scopes', () {
      var json = provider.metadataOf(_metadata.copyWith(scopes: ['profile']));
      expect(json['scopes_supported'], ['openid', 'profile']);
    });

    test('an ID token of requireAuthTime must be given its authTime', () {
      expect(
        () => provider.issueIdToken(
          user: 'alice',
          client: 'app',
          requireAuthTime: true,
        ),
        throwsArgumentError,
      );
      provider.issueIdToken(
        user: 'alice',
        client: 'app',
        requireAuthTime: true,
        authTime: DateTime.now(),
      );
    });

    test('an ID token of a client of ES256 is signed with the ES256 key', () {
      var token = provider.issueIdToken(user: 'alice', client: 'es-app');
      expect(_headerOf(token), containsPair('alg', 'ES256'));
      expect(_headerOf(token), containsPair('kid', 'ec'));
      expect(
        _headerOf(provider.issueIdToken(user: 'alice', client: 'app')),
        containsPair('alg', 'RS256'),
      );
      expect(
        () => provider.issueIdToken(
          user: 'alice',
          client: 'app',
          algorithm: 'PS256',
        ),
        throwsStateError,
      );
    });

    group('logout', () {
      Future<http.Response> logout(
        Map<String, String> params, {
        bool post = false,
      }) => post
          ? client.post(Uri.parse('/oauth2/logout'), body: params)
          : client.get(Uri(path: '/oauth2/logout', queryParameters: params));

      String hint({DateTime? now}) =>
          provider.issueIdToken(user: 'alice', client: 'app', now: now);

      test(
        'signs the user of the hint out, and redirects of the state',
        () async {
          for (var post in [false, true]) {
            provider.ended.clear();
            var response = await logout({
              'id_token_hint': hint(),
              'post_logout_redirect_uri': '$_postLogout',
              'state': 'st',
            }, post: post);
            expect(response.statusCode, 302, reason: response.body);
            expect(
              response.headers['location'],
              'https://app.example/signed-out?state=st',
            );
            var ended = provider.ended.single;
            expect(ended.subject, 'alice');
            expect(ended.client, 'app');
            expect(ended.hasIdTokenHint, isTrue);
          }
        },
      );

      test('of an expired hint, as one may be', () async {
        var response = await logout({
          'id_token_hint': hint(now: DateTime(2020)),
        });
        expect(response.statusCode, 200, reason: response.body);
        expect(json.decode(response.body), {'signed_out': true});
        expect(provider.ended.single.subject, 'alice');
      });

      test('of no hint, of nothing to check, signs out alike', () async {
        var response = await logout({});
        expect(response.statusCode, 200);
        expect(provider.ended.single.hasIdTokenHint, isFalse);
      });

      test(
        'refuses a request that is not valid, and never redirects it',
        () async {
          var foreign = OpenIdSigningKey.generate(
            keyId: 'rsa',
            algorithm: 'ES256',
          );
          for (var params in [
            // Of a key that is not the provider's, of the same kid.
            {
              'id_token_hint': foreign.signJwt({'iss': '$_issuer', 'sub': 'x'}),
            },
            {'id_token_hint': 'not.a.token'},
            // Of the provider's keys, but not ID tokens: of another type, of a
            // logout token's `events`, or of a `sub` that is not a string.
            {'id_token_hint': _typed('at+jwt')},
            {
              'id_token_hint': _rsa.signJwt({
                'iss': '$_issuer',
                'sub': 'alice',
                'aud': 'app',
                'events': {
                  'http://schemas.openid.net/event/backchannel-logout': {},
                },
              }),
            },
            {
              'id_token_hint': _rsa.signJwt({
                'iss': '$_issuer',
                'sub': 123,
                'aud': 'app',
              }),
            },
            // Of the provider's key, of another issuer, as of one key of two.
            {
              'id_token_hint': _rsa.signJwt({
                'iss': 'https://other.example',
                'sub': 'x',
                'aud': 'app',
              }),
            },
            // Of a client that is not the audience of the hint.
            {'id_token_hint': hint(), 'client_id': 'es-app'},
            // Of a redirect of no client, or not registered for it.
            {'post_logout_redirect_uri': '$_postLogout'},
            {
              'client_id': 'app',
              'post_logout_redirect_uri': 'https://evil.example/',
            },
            {'client_id': 'unknown'},
          ]) {
            var response = await logout(params);
            expect(response.statusCode, 400, reason: '$params');
            expect(response.headers, isNot(contains('location')));
          }
          expect(provider.ended, isEmpty);
        },
      );

      test(
        'of a hint of several audiences, of the client_id of one of them',
        () async {
          var several = _rsa.signJwt({
            'iss': '$_issuer',
            'sub': 'alice',
            'aud': ['app', 'es-app'],
          });
          var response = await logout({
            'id_token_hint': several,
            'client_id': 'es-app',
          });
          expect(response.statusCode, 200, reason: response.body);
          expect(provider.ended.single.client, 'es-app');
          // Of no client_id, of which the client is not known.
          response = await logout({'id_token_hint': several});
          expect(response.statusCode, 400);
        },
      );

      test(
        'refuses a hint of no audience, and a body it cannot read',
        () async {
          var none = _rsa.signJwt({'iss': '$_issuer', 'sub': 'x', 'aud': []});
          expect((await logout({'id_token_hint': none})).statusCode, 400);
          var response = await client.post(
            Uri.parse('/oauth2/logout'),
            headers: {'content-type': 'application/x-www-form-urlencoded'},
            body: 'state=%E0%A4%A',
          );
          expect(response.statusCode, 400);
          expect(provider.ended, isEmpty);
        },
      );

      test('is refused by default, a 403', () async {
        var plain = _Plain();
        var app = Angel()..get('/logout', plain.endSessionEndpoint);
        app.errorHandler = (e, req, res) async {
          res.statusCode = e.statusCode;
          res.json(e.toJson());
        };
        var other = await connectTo(app);
        expect((await other.get(Uri.parse('/logout'))).statusCode, 403);
        await other.close();
      });
    });

    test('the configuration has the end session endpoint, prompt values, and '
        'no request objects', () async {
      var config = json.decode(
        (await client.get(Uri.parse(openIdConfigurationPath))).body,
      ) as Map;
      expect(
        config['end_session_endpoint'],
        'https://id.example/oauth2/logout',
      );
      expect(config['prompt_values_supported'], [
        'none',
        'login',
        'consent',
        'select_account',
      ]);
      expect(config['request_uri_parameter_supported'], isFalse);
      expect(config['request_parameter_supported'], isFalse);
      expect(config['claims_parameter_supported'], isFalse);
      expect(
        config['id_token_signing_alg_values_supported'],
        unorderedEquals(['RS256', 'ES256']),
      );
    });
  });
}

/// A provider of the clients `app` and `es-app`, of ES256 ID tokens, of
/// which no user is signed in, which registers clients and records logouts.
class _Provider extends OpenIdServer<String, String> {
  _Provider() : super(issuer: _issuer, signingKeys: [_rsa, _ec]);

  final registered = <ClientRegistration>[];
  final ended = <EndSessionRequest<String>>[];

  @override
  String? findClient(String? clientId) =>
      const {'app', 'es-app'}.contains(clientId) ? clientId : null;

  @override
  bool verifyClient(String client, String? clientSecret) => true;

  @override
  Uri? registeredRedirectUri(String client, String? redirectUri) =>
      _redirectUri;

  @override
  String clientIdOf(String client) => client;

  @override
  String subjectOf(String user) => user;

  @override
  String? idTokenAlgorithmOf(String client) =>
      client == 'es-app' ? 'ES256' : null;

  @override
  Iterable<Uri> postLogoutRedirectUrisOf(String client) =>
      client == 'app' ? [_postLogout] : const [];

  @override
  void endSession(
    EndSessionRequest<String> request,
    RequestContext req,
    ResponseContext res,
  ) => ended.add(request);

  @override
  bool mayRegisterClient(String? initialAccessToken, RequestContext req) =>
      true;

  @override
  void registerClient(ClientRegistration registration, RequestContext req) =>
      registered.add(registration);

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
    // No user is signed in.
    req.container!.make<OpenIdRequest>().interactions(signedIn: false);
    throw StateError('A user is to sign in here.');
  }
}

/// A provider of the defaults, of no logout.
class _Plain extends OpenIdServer<String, String> {
  _Plain({List<OpenIdSigningKey>? keys})
    : super(issuer: _issuer, signingKeys: keys ?? [_rsa]);

  @override
  String? findClient(String? clientId) => clientId;

  @override
  bool verifyClient(String client, String? clientSecret) => true;

  @override
  String clientIdOf(String client) => client;

  @override
  String subjectOf(String user) => user;
}

/// A JWT of the provider's RS256 key, of the header type [type], of the
/// claims of an ID token.
String _typed(String type) {
  String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
  var header = b64(
    utf8.encode(json.encode({'alg': 'RS256', 'kid': 'rsa', 'typ': type})),
  );
  var payload = b64(
    utf8.encode(json.encode({'iss': '$_issuer', 'sub': 'alice', 'aud': 'app'})),
  );
  var input = '$header.$payload';
  return '$input.${b64(_rsa.sign(ascii.encode(input)))}';
}

/// A provider of hooks of plain return types, as the hooks of
/// angel3_auth_server have them: of `FutureOr`, so that it compiles.
class _Sync extends OpenIdServer<String, String> {
  _Sync() : super(issuer: _issuer, signingKeys: [_rsa]);

  @override
  String? findClient(String? clientId) => clientId;

  @override
  bool verifyClient(String client, String? clientSecret) => true;

  @override
  String clientIdOf(String client) => client;

  @override
  String subjectOf(String user) => user;

  @override
  void checkAuthorizationRequest(
    String client,
    Map<String, dynamic> params,
    String state,
    RequestContext req,
  ) {
    super.checkAuthorizationRequest(client, params, state, req);
    // Registered before super, awaited or not.
    req.container!.make<OpenIdRequest>();
  }
}
