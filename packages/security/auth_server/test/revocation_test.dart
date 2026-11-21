import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'common.dart';

typedef _Token = AccessToken<PseudoApplication, PseudoUser>;

/// A public client, without a secret.
const _publicClient = PseudoApplication('public', '', 'http://foo.bar');

void main() {
  late TestClient client;
  late _Server server;

  /// Connects to [authorizationServer], of a revocation endpoint and a
  /// resource that its tokens protect.
  Future<TestClient> connect(AuthorizationServer authorizationServer) async {
    var app = Angel();
    app
      ..post('/oauth2/revoke', authorizationServer.revocationEndpoint)
      ..get(
        '/me',
        chain([authorizationServer.requireToken(), (req, res) => 'me']),
      );
    app.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    return connectTo(app);
  }

  setUp(() async {
    server = _Server();
    client = await connect(server);
  });

  tearDown(() => client.close());

  final basic = 'Basic ${base64.encode('foo:bar'.codeUnits)}';

  Future<http.Response> revoke(
    Map<String, String> body, {
    String? authorization,
  }) => client.post(
    Uri.parse('/oauth2/revoke'),
    headers: {'authorization': ?authorization},
    body: body,
  );

  test('a client revokes its token, which then protects nothing', () async {
    expect(
      await client.get(
        Uri.parse('/me'),
        headers: {'authorization': 'Bearer access'},
      ),
      hasStatus(200),
    );
    var response = await revoke({
      'token': 'access',
      'token_type_hint': 'access_token',
    }, authorization: basic);
    expect(response, hasStatus(200));
    expect(response.body, isEmpty);
    expect(response.headers['cache-control'], 'no-store');
    expect(server.revoked, ['access']);
    expect(server.lastHint, 'access_token');
    expect(
      await client.get(
        Uri.parse('/me'),
        headers: {'authorization': 'Bearer access'},
      ),
      hasStatus(401),
    );
  });

  test('an unknown token, or one of another client, is a 200', () async {
    for (var token in ['nope', 'public-token']) {
      var response = await revoke({'token': token}, authorization: basic);
      expect(response, hasStatus(200));
      expect(response.body, isEmpty);
    }
    expect(server.revoked, isEmpty);
    expect(server.lastHint, isNull);
  });

  test('a public client gives its client_id alone', () async {
    var response = await revoke({
      'client_id': 'public',
      'token': 'public-token',
    });
    expect(response, hasStatus(200));
    expect(server.revoked, ['public-token']);
  });

  test('the client is authenticated', () async {
    var response = await revoke({
      'client_id': 'foo',
      'client_secret': 'wrong',
      'token': 'access',
    });
    expect(response, hasStatus(401));
    expect(json.decode(response.body), containsPair('error', 'invalid_client'));
    expect(server.revoked, isEmpty);
  });

  test('a request without a token is invalid_request', () async {
    var response = await revoke({}, authorization: basic);
    expect(response, hasStatus(400));
    expect(
      json.decode(response.body),
      containsPair('error', 'invalid_request'),
    );
  });

  test('without revokeToken, it is unsupported_token_type', () async {
    var defaultClient = await connect(_DefaultServer());
    try {
      var response = await defaultClient.post(
        Uri.parse('/oauth2/revoke'),
        headers: {'authorization': basic},
        body: {'token': 'access'},
      );
      expect(response, hasStatus(400));
      expect(
        json.decode(response.body),
        containsPair('error', 'unsupported_token_type'),
      );
    } finally {
      await defaultClient.close();
    }
  });
}

class _DefaultServer
    extends AuthorizationServer<PseudoApplication, PseudoUser> {
  @override
  PseudoApplication? findClient(String? clientId) =>
      clientId == 'foo' ? pseudoApplication : null;

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) =>
      client.secret == clientSecret;
}

class _Server extends _DefaultServer {
  /// The tokens that the server issued.
  final tokens = <String, _Token>{
    'access': _Token(client: pseudoApplication, user: pseudoUsers.first),
    'public-token': _Token(client: _publicClient, user: pseudoUsers.first),
  };

  final revoked = <String>[];

  String? lastHint;

  @override
  PseudoApplication? findClient(String? clientId) =>
      clientId == 'public' ? _publicClient : super.findClient(clientId);

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) =>
      identical(client, _publicClient)
      ? clientSecret == null
      : super.verifyClient(client, clientSecret);

  @override
  _Token? findAccessToken(String token, RequestContext req) => tokens[token];

  @override
  void revokeToken(
    PseudoApplication client,
    String token,
    String? tokenTypeHint,
    RequestContext req,
    ResponseContext res,
  ) {
    lastHint = tokenTypeHint;
    // Only a token of the client.
    if (identical(tokens[token]?.client, client)) {
      tokens.remove(token);
      revoked.add(token);
    }
  }
}
