import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'common.dart';

typedef _Token = AccessToken<PseudoApplication, PseudoUser>;

/// The tokens that the server issued.
final _tokens = <String, _Token>{
  'read-token': _Token(
    client: pseudoApplication,
    user: pseudoUsers.first,
    scopes: ['read'],
  ),
  'all+tok/en=': _Token(
    client: pseudoApplication,
    user: pseudoUsers.first,
    scopes: ['read', 'write'],
  ),
  'client-token': _Token(client: pseudoApplication, scopes: ['read']),
  'expired-token': _Token(
    client: pseudoApplication,
    scopes: ['read'],
    expiresAt: DateTime.now().subtract(Duration(minutes: 1)),
  ),
};

void main() {
  late TestClient client;

  setUp(() async {
    var app = Angel();
    var server = _Server();

    String? me(RequestContext req, ResponseContext res) {
      var token = req.container!.make<_Token>();
      return token.user?.username ?? 'client ${token.client!.id}';
    }

    app
      ..get('/me', chain([server.requireToken(), me]))
      ..post(
        '/write',
        chain([
          server.requireToken(scopes: ['read']),
          server.requireToken(scopes: ['write'], allowFormParameter: true),
          me,
        ]),
      )
      ..post('/form', chain([server.requireToken(), me]));
    app.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    client = await connectTo(app);
  });

  tearDown(() => client.close());

  Future<http.Response> get(String path, {String? authorization}) =>
      client.get(Uri.parse(path), headers: {'authorization': ?authorization});

  /// Expects [response] to be refused with [error], of [status].
  void expectRefused(
    http.Response response,
    int status,
    String error, {
    String? scope,
  }) {
    expect(response, hasStatus(status));
    var challenge = response.headers['www-authenticate']!;
    expect(challenge, startsWith('Bearer realm="oauth2", error="$error"'));
    if (scope != null) expect(challenge, endsWith('scope="$scope"'));
    expect(json.decode(response.body), containsPair('error', error));
  }

  test('a valid token reaches the resource, with its user', () async {
    var response = await get('/me', authorization: 'Bearer read-token');
    expect(response, hasStatus(200));
    expect(json.decode(response.body), pseudoUsers.first.username);
  });

  test('a token of a client credentials grant has no user', () async {
    var response = await get('/me', authorization: 'Bearer client-token');
    expect(json.decode(response.body), 'client foo');
  });

  test('the scheme is of any case, the token of any b64token', () async {
    expect(
      await get('/me', authorization: 'bearer read-token'),
      hasStatus(200),
    );
    expect(
      await get('/me', authorization: 'Bearer all+tok/en='),
      hasStatus(200),
    );
  });

  test('no token is a 401 challenge, without an error', () async {
    for (var authorization in [
      null,
      'Basic ${base64.encode('a:b'.codeUnits)}',
    ]) {
      var response = await get('/me', authorization: authorization);
      expect(response, hasStatus(401));
      expect(response.headers['www-authenticate'], 'Bearer realm="oauth2"');
    }
  });

  test('a token in the query is not read', () async {
    var response = await get('/me?access_token=read-token');
    expect(response, hasStatus(401));
  });

  test('an unknown token is invalid_token', () async {
    expectRefused(
      await get('/me', authorization: 'Bearer nope'),
      401,
      'invalid_token',
    );
  });

  test('an expired token is invalid_token', () async {
    var response = await get('/me', authorization: 'Bearer expired-token');
    expectRefused(response, 401, 'invalid_token');
    expect(response.body, contains('expired'));
  });

  test('a malformed token is invalid_request', () async {
    for (var authorization in ['Bearer', 'Bearer a b', 'Bearer a"b']) {
      expectRefused(
        await get('/me', authorization: authorization),
        400,
        'invalid_request',
      );
    }
  });

  test('two tokens are invalid_request', () async {
    expectRefused(
      await get('/me', authorization: 'Bearer read-token,Bearer client-token'),
      400,
      'invalid_request',
    );
  });

  group('scopes', () {
    test('a token without them is insufficient_scope, a 403', () async {
      var response = await client.post(
        Uri.parse('/write'),
        headers: {'authorization': 'Bearer read-token'},
      );
      expectRefused(response, 403, 'insufficient_scope', scope: 'write');
    });

    test('a token with them passes several requireToken', () async {
      var response = await client.post(
        Uri.parse('/write'),
        headers: {'authorization': 'Bearer all+tok/en='},
      );
      expect(response, hasStatus(200));
    });
  });

  group('the form parameter', () {
    test('is read only if allowed', () async {
      var allowed = await client.post(
        Uri.parse('/write'),
        body: {'access_token': 'all+tok/en='},
      );
      // Of the first requireToken, which does not allow it.
      expect(allowed, hasStatus(401));
      var refused = await client.post(
        Uri.parse('/form'),
        body: {'access_token': 'read-token'},
      );
      expect(refused, hasStatus(401));
    });

    test('with the header too is invalid_request', () async {
      var app = Angel();
      app.post(
        '/form',
        chain([
          _Server().requireToken(allowFormParameter: true),
          (req, res) => 'ok',
        ]),
      );
      app.errorHandler = (e, req, res) async {
        res.statusCode = e.statusCode;
        res.json(e.toJson());
      };
      var formClient = await connectTo(app);
      try {
        expect(
          await formClient.post(
            Uri.parse('/form'),
            body: {'access_token': 'read-token'},
          ),
          hasStatus(200),
        );
        expectRefused(
          await formClient.post(
            Uri.parse('/form'),
            headers: {'authorization': 'Bearer read-token'},
            body: {'access_token': 'read-token'},
          ),
          400,
          'invalid_request',
        );
        Future<http.Response> form(String body) => formClient.post(
          Uri.parse('/form'),
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: body,
        );
        // The app's own fields may be given more than once.
        expect(
          await form('access_token=read-token&tag=a&tag=b'),
          hasStatus(200),
        );
        // Not the access token.
        expectRefused(
          await form('access_token=read-token&access_token=read-token'),
          400,
          'invalid_request',
        );
      } finally {
        await formClient.close();
      }
    });
  });
}

class _Server extends AuthorizationServer<PseudoApplication, PseudoUser> {
  @override
  PseudoApplication? findClient(String? clientId) => pseudoApplication;

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) => true;

  @override
  _Token? findAccessToken(String token, RequestContext req) => _tokens[token];
}
