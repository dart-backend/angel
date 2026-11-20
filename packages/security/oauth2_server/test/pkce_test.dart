import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_oauth2_server/angel3_oauth2_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'common.dart';

/// A verifier of 43 `a`s, and its S256 challenge.
final _verifier = 'a' * 43;
const _challenge = 'ZtNPunH49FD35FWYhT5Tv8I7vRKQJ8uxMaL0_9eHjNA';

void main() {
  late TestClient testClient;

  /// Connects to a server, [lenient] of PKCE, as of 9.x, or by default; or
  /// that requires PKCE, but [allowsPlain].
  Future<void> connect({required bool lenient, bool? allowsPlain}) async {
    var app = Angel();
    app.container.registerSingleton(AuthCodes());
    var server = _Server(
      requires: !lenient,
      allowsPlain: allowsPlain ?? lenient,
    );
    app.group('/oauth2', (router) {
      router
        ..get('/authorize', server.authorizationEndpoint)
        ..post('/token', server.tokenEndpoint);
    });
    app.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    testClient = await connectTo(app);
  }

  tearDown(() => testClient.close());

  Future<http.Response> authorize(Map<String, String> query) => testClient.get(
    Uri(
      path: '/oauth2/authorize',
      queryParameters: {
        'response_type': 'code',
        'client_id': 'foo',
        'redirect_uri': 'https://freddie.mercu.ry',
        ...query,
      },
    ),
  );

  Future<http.Response> token(Map<String, String> body) => testClient.post(
    Uri.parse('/oauth2/token'),
    headers: {
      'authorization':
          'Basic ${base64.encode('${pseudoApplication.id}:'
              '${pseudoApplication.secret}'.codeUnits)}',
    },
    body: {
      'grant_type': 'authorization_code',
      'redirect_uri': 'https://freddie.mercu.ry',
      'code': 'ok',
      ...body,
    },
  );

  void expectInvalidRequest(http.Response response, String description) {
    expect(
      response,
      allOf(
        hasStatus(400),
        isJson({'error': 'invalid_request', 'error_description': description}),
      ),
    );
  }

  const mustBeS256 = 'The "code_challenge_method" parameter must be "S256".';

  group('by default, S256 is required', () {
    setUp(() => connect(lenient: false));

    group('get auth code', () {
      test('with an S256 challenge', () async {
        for (var method in ['S256', 's256']) {
          var response = await authorize({
            'code_challenge': _challenge,
            'code_challenge_method': method,
          });
          expect(response, allOf(hasStatus(200), isJson({'code': 'ok'})));
        }
      });

      test('with a padded S256 challenge, as earlier clients gave', () async {
        var response = await authorize({
          'code_challenge': '$_challenge=',
          'code_challenge_method': 'S256',
        });
        expect(response, hasStatus(200));
      });

      test('with challenge + implied plain', () async {
        expectInvalidRequest(
          await authorize({'code_challenge': _challenge}),
          mustBeS256,
        );
      });

      test('with challenge + plain', () async {
        expectInvalidRequest(
          await authorize({
            'code_challenge': _challenge,
            'code_challenge_method': 'plain',
          }),
          mustBeS256,
        );
      });

      test('with challenge + wrong method', () async {
        expectInvalidRequest(
          await authorize({
            'code_challenge': _challenge,
            'code_challenge_method': 'bar',
          }),
          mustBeS256,
        );
      });

      test('with no challenge', () async {
        expectInvalidRequest(
          await authorize({}),
          'Missing "code_challenge" parameter; PKCE is required.',
        );
      });

      test('with a challenge that is too short', () async {
        var response = await authorize({
          'code_challenge': 'foo',
          'code_challenge_method': 'S256',
        });
        expect(response, hasStatus(400));
        expect(response.body, contains('43 characters'));
      });

      test('an S256 challenge of more than 43 characters', () async {
        for (var challenge in [
          'a' * 44,
          '${'a' * 42}.~',
          'a' * 128,
          '$_challenge==',
        ]) {
          var response = await authorize({
            'code_challenge': challenge,
            'code_challenge_method': 'S256',
          });
          expect(response, hasStatus(400), reason: challenge);
          expect(response.body, contains('of an S256 challenge'));
        }
      });

      test('an implicit grant has no PKCE', () async {
        var response = await authorize({'response_type': 'token'});
        expect(response, hasStatus(200));
      });
    });

    group('get token', () {
      test('with correct verifier', () async {
        expect(
          await token({'code_verifier': _verifier}),
          allOf(
            hasStatus(200),
            isJson({'token_type': 'bearer', 'access_token': 'yes'}),
          ),
        );
        // Of the stored challenge, not of the request, which has none.
        expect(_Server.tokenHadPkce, isFalse);
      });

      test('with incorrect verifier', () async {
        expect(
          await token({'code_verifier': 'b' * 43}),
          allOf(
            hasStatus(400),
            isJson({
              'error': 'invalid_grant',
              'error_description':
                  'The given `code_verifier` parameter is invalid.',
            }),
          ),
        );
      });

      test('with missing verifier', () async {
        expectInvalidRequest(
          await token({}),
          'Missing "code_verifier" parameter; PKCE is required.',
        );
      });

      test('with a verifier that is too short', () async {
        var response = await token({'code_verifier': 'hello'});
        expect(response, hasStatus(400));
        expect(response.body, contains('43 to 128 characters'));
      });
    });
  });

  group('required, of plain allowed', () {
    setUp(() => connect(lenient: false, allowsPlain: true));

    test('a plain challenge is accepted, of no padding', () async {
      expect(
        await authorize({
          'code_challenge': 'a' * 43,
          'code_challenge_method': 'plain',
        }),
        hasStatus(200),
      );
      var response = await authorize({
        'code_challenge': '${'a' * 43}=',
        'code_challenge_method': 'plain',
      });
      expect(response, hasStatus(400));
      expect(response.body, contains('43 to 128 characters'));
    });
  });

  group('lenient, as of requiresPkce and allowsPlainPkce', () {
    setUp(() => connect(lenient: true));

    test('plain, or no method, is accepted', () async {
      for (var query in [
        {'code_challenge': 'foo'},
        {'code_challenge': 'foo', 'code_challenge_method': 'plain'},
      ]) {
        var response = await authorize(query);
        expect(response, allOf(hasStatus(200), isJson({'code': 'ok'})));
      }
    });

    test('no challenge is left to the server', () async {
      // Of `req.container!.make<Pkce>()`, of requestAuthorizationCode.
      expectInvalidRequest(
        await authorize({}),
        'Missing `code_challenge` parameter.',
      );
    });

    test('an unknown method is refused all the same', () async {
      expectInvalidRequest(
        await authorize({
          'code_challenge': 'foo',
          'code_challenge_method': 'bar',
        }),
        'The "code_challenge_method" parameter must be "S256" or "plain".',
      );
    });

    test('an empty verifier is missing', () async {
      expectInvalidRequest(
        await token({'code_verifier': ''}),
        'Missing `code_verifier` parameter.',
      );
    });

    test('a short plain verifier is left to the server', () async {
      expect(await token({'code_verifier': 'hello'}), hasStatus(200));
      expectInvalidRequest(
        await token({}),
        'Missing `code_verifier` parameter.',
      );
    });
  });
}

class _Server extends AuthorizationServer<PseudoApplication, Map> {
  final bool requires, allowsPlain;

  _Server({required this.requires, required this.allowsPlain});

  bool get lenient => !requires;

  /// Whether the container of the last token request had a [Pkce].
  static bool? tokenHadPkce;

  @override
  FutureOr<PseudoApplication> findClient(String? clientId) {
    return pseudoApplication;
  }

  @override
  Future<bool> verifyClient(
    PseudoApplication client,
    String? clientSecret,
  ) async {
    return client.secret == clientSecret;
  }

  @override
  bool requiresPkce(PseudoApplication client) => requires;

  @override
  bool get allowsPlainPkce => allowsPlain;

  @override
  bool allowsImplicitGrant(PseudoApplication client) => true;

  @override
  Future requestAuthorizationCode(
    PseudoApplication client,
    String? redirectUri,
    Iterable<String> scopes,
    String state,
    RequestContext req,
    ResponseContext res,
    bool implicit,
  ) async {
    if (!implicit) req.container!.make<Pkce>();
    return {'code': 'ok'};
  }

  @override
  Future<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
    PseudoApplication? client,
    String? authCode,
    String? redirectUri,
    RequestContext req,
    ResponseContext res,
  ) async {
    tokenHadPkce = req.container!.has<Pkce>();
    var codeVerifier = await getPkceCodeVerifier(req);
    // The challenge stored with the code.
    var pkce = lenient ? Pkce('plain', 'hello') : Pkce('S256', _challenge);
    pkce.validate(codeVerifier);
    return AuthorizationTokenResponse('yes');
  }
}

class AuthCodes with MapMixin<String, String> {
  var inner = <String, String>{};

  @override
  String? operator [](Object? key) => inner[key as String];

  @override
  void operator []=(String key, String value) => inner[key] = value;

  @override
  void clear() => inner.clear();

  @override
  Iterable<String> get keys => inner.keys;

  @override
  String? remove(Object? key) => inner.remove(key);
}
