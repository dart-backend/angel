import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_oauth2_server/angel3_oauth2_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'common.dart';

typedef _Token = AccessToken<PseudoApplication, PseudoUser>;

/// A public client, without a secret.
const _publicClient = PseudoApplication('public', '', 'http://foo.bar');

/// A resource server, which tokens of the `admin` scope are not for.
const _otherApi = PseudoApplication('other-api', 'secret', 'http://foo.bar');

/// A confidential client that is no resource server.
const _webApp = PseudoApplication('web-app', 'secret', 'http://foo.bar');

final _issuedAt = DateTime.utc(2026, 1, 1);
final _expiresAt = DateTime.now().add(Duration(hours: 1));

/// A refresh token, which [_Server.introspectToken] finds by its hint.
const _refreshToken = _Token(client: pseudoApplication, scopes: ['read']);

final _tokens = <String, _Token>{
  'access': _Token(
    client: pseudoApplication,
    user: pseudoUsers.first,
    scopes: ['read', 'write'],
    expiresAt: _expiresAt,
    issuedAt: _issuedAt,
  ),
  'admin': _Token(client: pseudoApplication, scopes: ['admin']),
  'expired': _Token(
    client: pseudoApplication,
    expiresAt: DateTime.now().subtract(Duration(minutes: 1)),
  ),
};

void main() {
  late TestClient client;

  setUp(() async {
    var app = Angel();
    var server = _Server();
    app.post('/oauth2/introspect', server.introspectionEndpoint);
    app.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    client = await connectTo(app);
  });

  tearDown(() => client.close());

  Future<http.Response> introspect(
    Map<String, String> body, {
    String credentials = 'foo:bar',
  }) => client.post(
    Uri.parse('/oauth2/introspect'),
    headers: {'authorization': 'Basic ${base64.encode(credentials.codeUnits)}'},
    body: body,
  );

  Future<Map> introspected(
    Map<String, String> body, {
    String? credentials,
  }) async {
    var response = credentials == null
        ? await introspect(body)
        : await introspect(body, credentials: credentials);
    expect(response, hasStatus(200));
    expect(response.headers['cache-control'], 'no-store');
    return json.decode(response.body) as Map;
  }

  test('an active token, with its scope, times and claims', () async {
    expect(await introspected({'token': 'access'}), {
      'active': true,
      'scope': 'read write',
      'exp': _expiresAt.millisecondsSinceEpoch ~/ 1000,
      'iat': _issuedAt.millisecondsSinceEpoch ~/ 1000,
      'client_id': 'foo',
      'username': pseudoUsers.first.username,
      'token_type': 'Bearer',
    });
  });

  test('an unknown or expired token is inactive, of nothing more', () async {
    for (var token in ['nope', 'expired']) {
      expect(await introspected({'token': token}), {'active': false});
    }
  });

  test('a token that the caller may not learn of is inactive', () async {
    expect(
      await introspected({'token': 'admin'}, credentials: 'other-api:secret'),
      {'active': false},
    );
    expect(
      await introspected({'token': 'admin'}),
      containsPair('active', true),
    );
  });

  test('a refresh token, of an introspectToken that finds them', () async {
    expect(
      await introspected({
        'token': 'refresh',
        'token_type_hint': 'refresh_token',
      }),
      containsPair('token_type', 'refresh_token'),
    );
    expect(await introspected({'token': 'refresh'}), {'active': false});
  });

  test('the caller must give a secret', () async {
    var response = await client.post(
      Uri.parse('/oauth2/introspect'),
      body: {'client_id': 'public', 'token': 'access'},
    );
    expect(response, hasStatus(401));
    expect(json.decode(response.body), containsPair('error', 'invalid_client'));
    expect(
      await introspect({'token': 'access'}, credentials: 'foo:wrong'),
      hasStatus(401),
    );
  });

  test('a client that is no resource server may not introspect', () async {
    var response = await introspect({
      'token': 'access',
    }, credentials: 'web-app:secret');
    expect(response, hasStatus(403));
    expect(json.decode(response.body), containsPair('error', 'access_denied'));
  });

  test('no client may introspect by default', () async {
    var app = Angel()..post('/i', _DefaultServer().introspectionEndpoint);
    app.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    var other = await connectTo(app);
    try {
      var response = await other.post(
        Uri.parse('/i'),
        headers: {
          'authorization': 'Basic ${base64.encode('foo:bar'.codeUnits)}',
        },
        body: {'token': 'access'},
      );
      expect(response, hasStatus(403));
    } finally {
      await other.close();
    }
  });

  test('a request without a token is invalid_request', () async {
    var response = await introspect({});
    expect(response, hasStatus(400));
    expect(
      json.decode(response.body),
      containsPair('error', 'invalid_request'),
    );
  });

  test('the metadata gives the endpoint, without none', () {
    var json = _Server().metadataOf(
      ServerMetadata(
        issuer: Uri.parse('https://example.com'),
        introspectionEndpoint: Uri.parse('https://example.com/introspect'),
        clientAuthMethods: ['client_secret_basic', 'none'],
      ),
    );
    expect(json['introspection_endpoint'], 'https://example.com/introspect');
    expect(json['introspection_endpoint_auth_methods_supported'], [
      'client_secret_basic',
    ]);
  });
}

class _Server extends AuthorizationServer<PseudoApplication, PseudoUser> {
  @override
  PseudoApplication? findClient(String? clientId) => switch (clientId) {
    'foo' => pseudoApplication,
    'public' => _publicClient,
    'other-api' => _otherApi,
    'web-app' => _webApp,
    _ => null,
  };

  @override
  bool mayIntrospect(PseudoApplication caller, RequestContext req) =>
      !identical(caller, _webApp);

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) =>
      client.secret.isEmpty
      ? clientSecret == null
      : client.secret == clientSecret;

  @override
  _Token? findAccessToken(String token, RequestContext req) => _tokens[token];

  @override
  _Token? introspectToken(
    String token,
    String? tokenTypeHint,
    RequestContext req,
  ) {
    if (tokenTypeHint == 'refresh_token' && token == 'refresh') {
      return _refreshToken;
    }
    return findAccessToken(token, req);
  }

  @override
  Map<String, dynamic>? introspectionClaims(
    PseudoApplication caller,
    _Token token,
  ) {
    if (token.scopes.contains('admin') && identical(caller, _otherApi)) {
      return null;
    }
    return {
      'client_id': token.client?.id,
      'username': ?token.user?.username,
      'token_type': identical(token, _refreshToken)
          ? 'refresh_token'
          : 'Bearer',
      // Which the server's own `active` replaces.
      'active': false,
    };
  }
}

class _DefaultServer
    extends AuthorizationServer<PseudoApplication, PseudoUser> {
  @override
  PseudoApplication? findClient(String? clientId) => pseudoApplication;

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) =>
      client.secret == clientSecret;

  @override
  _Token? findAccessToken(String token, RequestContext req) => _tokens[token];
}
