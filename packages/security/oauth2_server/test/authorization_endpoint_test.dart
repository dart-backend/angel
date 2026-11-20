import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_oauth2_server/angel3_oauth2_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'common.dart';

/// The PKCE of an authorization request, of a verifier of 43 `a`s.
const _pkce = {
  'code_challenge': 'ZtNPunH49FD35FWYhT5Tv8I7vRKQJ8uxMaL0_9eHjNA',
  'code_challenge_method': 'S256',
};

/// The redirect URI registered for [pseudoApplication].
final _registered = Uri.parse('http://foo.bar/cb?x=1');

void main() {
  late TestClient client;

  /// Connects to a server of [registers], whose redirect URIs are known.
  Future<void> connect({
    required bool registers,
    bool allowsImplicit = true,
  }) async {
    var app = Angel();
    var server = _Server(registers: registers, allowsImplicit: allowsImplicit);
    app
      ..get('/oauth2/authorize', server.authorizationEndpoint)
      ..post('/oauth2/authorize', server.authorizationEndpoint);
    app.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    client = await connectTo(app);
  }

  tearDown(() => client.close());

  /// An authorization request of [query], with PKCE, which is required.
  Future<http.Response> authorize(Map<String, String> query) => client.get(
    Uri(path: '/oauth2/authorize', queryParameters: {..._pkce, ...query}),
  );

  group('with registered redirect URIs', () {
    setUp(() => connect(registers: true));

    test('the redirect_uri may be left out', () async {
      var response = await authorize({
        'response_type': 'code',
        'client_id': 'foo',
      });
      expect(response, hasStatus(200));
      expect(json.decode(response.body), {'redirect_uri': '$_registered'});
    });

    test('a redirect_uri that is not registered is not redirected', () async {
      var response = await authorize({
        'response_type': 'code',
        'client_id': 'foo',
        'redirect_uri': 'http://evil.example/',
        'state': 's',
      });
      expect(response, hasStatus(400));
      expect(response.headers, isNot(contains('location')));
      expect(
        json.decode(response.body),
        containsPair('error', 'invalid_request'),
      );
    });

    test('an error is redirected, in the query, with the state', () async {
      var response = await authorize({
        'response_type': 'code',
        'client_id': 'foo',
        'state': 's',
        'scope': 'deny',
      });
      expect(response, hasStatus(302));
      var location = Uri.parse(response.headers['location']!);
      expect(location.replace(query: ''), _registered.replace(query: ''));
      expect(location.queryParameters, {
        'x': '1',
        'error': 'access_denied',
        'error_description': 'The user denied access.',
        'state': 's',
      });
    });

    test('an error of an implicit grant is in the fragment', () async {
      var response = await authorize({
        'response_type': 'token',
        'client_id': 'foo',
        'state': 's',
        'scope': 'deny',
      });
      expect(response, hasStatus(302));
      var location = Uri.parse(response.headers['location']!);
      expect(location.query, 'x=1');
      expect(Uri.splitQueryString(location.fragment), {
        'error': 'access_denied',
        'error_description': 'The user denied access.',
        'state': 's',
      });
    });

    test('an implicit grant is refused by default, in the fragment', () async {
      await client.close();
      await connect(registers: true, allowsImplicit: false);
      var response = await authorize({
        'response_type': 'token',
        'client_id': 'foo',
        'state': 's',
        'scope': 'grant',
      });
      expect(response, hasStatus(302));
      var location = Uri.parse(response.headers['location']!);
      expect(
        Uri.splitQueryString(location.fragment),
        allOf(
          containsPair('error', 'unsupported_response_type'),
          containsPair('state', 's'),
        ),
      );
    });

    test('an unsupported response_type is redirected', () async {
      var response = await authorize({
        'response_type': 'nope',
        'client_id': 'foo',
      });
      expect(response, hasStatus(302));
      var location = Uri.parse(response.headers['location']!);
      expect(location.queryParameters['error'], 'unsupported_response_type');
    });

    test('an unknown client is invalid_request, not redirected', () async {
      var response = await authorize({
        'response_type': 'code',
        'client_id': 'nobody',
      });
      expect(response, hasStatus(400));
      expect(response.headers, isNot(contains('location')));
      expect(
        json.decode(response.body),
        containsPair('error', 'invalid_request'),
      );
    });

    test('an unexpected error is redirected as server_error', () async {
      var response = await authorize({
        'response_type': 'code',
        'client_id': 'foo',
        'state': 's',
        'scope': 'crash',
      });
      expect(response, hasStatus(302));
      var location = Uri.parse(response.headers['location']!);
      expect(location.queryParameters, {
        'x': '1',
        'error': 'server_error',
        'error_description': 'An internal server error occurred.',
        'state': 's',
      });
    });

    test('a code is redirected with completeAuthorizationCode', () async {
      var response = await authorize({
        'response_type': 'code',
        'client_id': 'foo',
        'state': 's',
        'scope': 'grant',
      });
      expect(response, hasStatus(302));
      var location = Uri.parse(response.headers['location']!);
      expect(location.queryParameters, {
        'x': '1',
        'code': 'c0de',
        'state': 's',
      });
    });

    test('the query of the redirect URI is kept as it is', () {
      var server = _Server(registers: true);
      var uri = Uri.parse('https://app.example/cb?flag&x=a%20b');
      expect(
        server.completeAuthorizationCode('c', uri, state: 's').toString(),
        'https://app.example/cb?flag&x=a%20b&code=c&state=s',
      );
    });

    test('the request may be a POST of a form', () async {
      var response = await client.post(
        Uri.parse('/oauth2/authorize'),
        body: {
          ..._pkce,
          'response_type': 'code',
          'client_id': 'foo',
          'state': 's',
        },
      );
      expect(response, hasStatus(200));
      expect(json.decode(response.body), {'redirect_uri': '$_registered'});
    });
  });

  group('by default', () {
    setUp(() => connect(registers: false));

    test('the redirect_uri is required', () async {
      var response = await authorize({
        'response_type': 'code',
        'client_id': 'foo',
      });
      expect(response, hasStatus(400));
      expect(
        json.decode(response.body),
        containsPair('error', 'invalid_request'),
      );
    });

    test('an unexpected error is not redirected', () async {
      var response = await authorize({
        'response_type': 'code',
        'client_id': 'foo',
        'redirect_uri': 'http://evil.example/',
        'scope': 'crash',
      });
      expect(response, hasStatus(500));
      expect(response.headers, isNot(contains('location')));
    });

    test('an error is not redirected', () async {
      var response = await authorize({
        'response_type': 'code',
        'client_id': 'foo',
        'redirect_uri': 'http://evil.example/',
        'scope': 'deny',
      });
      expect(response, hasStatus(403));
      expect(response.headers, isNot(contains('location')));
      expect(
        json.decode(response.body),
        containsPair('error', 'access_denied'),
      );
    });

    test('an unsupported response_type is unsupported_response_type', () async {
      var response = await authorize({
        'response_type': 'nope',
        'client_id': 'foo',
        'redirect_uri': 'http://foo.bar/cb',
      });
      expect(response, hasStatus(400));
      expect(
        json.decode(response.body),
        containsPair('error', 'unsupported_response_type'),
      );
    });
  });
}

class _Server extends AuthorizationServer<PseudoApplication, PseudoUser> {
  final bool registers, allowsImplicit;

  _Server({required this.registers, this.allowsImplicit = true});

  @override
  bool allowsImplicitGrant(PseudoApplication client) => allowsImplicit;

  @override
  PseudoApplication? findClient(String? clientId) =>
      clientId == pseudoApplication.id ? pseudoApplication : null;

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) =>
      client.secret == clientSecret;

  @override
  Uri? registeredRedirectUri(PseudoApplication client, String? redirectUri) {
    if (!registers) return null;
    if (redirectUri == null || redirectUri == '$_registered') {
      return _registered;
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
  Future<Map<String, String>> requestAuthorizationCode(
    PseudoApplication client,
    String? redirectUri,
    Iterable<String> scopes,
    String state,
    RequestContext req,
    ResponseContext res,
    bool implicit,
  ) async {
    if (scopes.contains('crash')) throw StateError('A bug.');
    if (scopes.contains('grant')) {
      await res.redirect(
        completeAuthorizationCode(
          'c0de',
          Uri.parse(redirectUri!),
          state: state,
        ),
      );
      return {};
    }
    if (scopes.contains('deny')) {
      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.accessDenied,
          'The user denied access.',
          state,
        ),
        statusCode: 403,
      );
    }
    return {'redirect_uri': '$redirectUri'};
  }
}
