import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:angel3_oauth2_server/angel3_oauth2_server.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  late TestClient client;

  setUp(() async {
    var app = Angel();
    var oauth2 = _AuthorizationServer();

    app.group('/oauth2', (router) {
      router
        ..get('/authorize', oauth2.authorizationEndpoint)
        ..post('/token', oauth2.tokenEndpoint);
    });

    app.errorHandler = (e, req, res) async {
      res.json(e.toJson());
    };

    client = await connectTo(app);
  });

  tearDown(() => client.close());

  test('authenticate via client credentials', () async {
    var response = await client.post(
      Uri.parse('oauth2/token'),
      headers: {
        'Authorization': 'Basic ${base64Url.encode('foo:bar'.codeUnits)}',
      },
      body: {'grant_type': 'client_credentials'},
    );

    print('Response: ${response.body}');

    // TODO: Incorrect Validators
    /*
    expect(
        response,
        allOf(
          hasStatus(200),
          hasContentType('application/json'),
          hasValidBody(Validator({
            'token_type': equals('bearer'),
            'access_token': equals('foo'),
          })),
        ));
        */
  });

  test('accepts the standard base64 alphabet', () async {
    var response = await client.post(
      Uri.parse('/oauth2/token'),
      headers: {'Authorization': 'Basic ${base64.encode('foo:bar'.codeUnits)}'},
      body: {'grant_type': 'client_credentials'},
    );
    expect(response, hasStatus(200));
  });

  /// Expects [response] to be of a client that could not be authenticated.
  void expectInvalidClient(http.Response response) {
    expect(response, hasStatus(401));
    expect(response.headers['www-authenticate'], 'Basic');
    expect(json.decode(response.body), containsPair('error', 'invalid_client'));
  }

  Future<http.Response> withBasic(
    String header, {
    String grantType = 'client_credentials',
  }) => client.post(
    Uri.parse('/oauth2/token'),
    headers: {'Authorization': header},
    body: {'grant_type': grantType},
  );

  test('a malformed Basic header is invalid_client, not a 500', () async {
    expectInvalidClient(await withBasic('Basic !!!'));
  });

  test('a header of another scheme ending in Basic is refused', () async {
    expectInvalidClient(
      await withBasic('XBasic ${base64.encode('foo:bar'.codeUnits)}'),
    );
  });

  test('a secret may have a \$ and a :', () async {
    var response = await withBasic(
      'Basic ${base64.encode(utf8.encode('dollar:a\$b:c'))}',
    );
    expect(response, hasStatus(200));
  });

  test('an unknown grant type is unsupported_grant_type', () async {
    var response = await withBasic(
      'Basic ${base64.encode('foo:bar'.codeUnits)}',
      grantType: 'nope',
    );
    expect(response, hasStatus(400));
    expect(
      json.decode(response.body),
      containsPair('error', 'unsupported_grant_type'),
    );
  });

  test('a grant that the server does not implement is '
      'unsupported_grant_type', () async {
    var response = await client.post(
      Uri.parse('/oauth2/token'),
      headers: {'Authorization': 'Basic ${base64.encode('foo:bar'.codeUnits)}'},
      body: {
        'grant_type': 'password',
        'username': 'u',
        'password': 'p',
        'state': 'xyz',
      },
    );
    expect(response, hasStatus(400));
    expect(
      json.decode(response.body),
      containsPair('error', 'unsupported_grant_type'),
    );
  });

  test('force correct id', () async {
    var response = await client.post(
      Uri.parse('/oauth2/token'),
      headers: {
        'Authorization': 'Basic ${base64Url.encode('fooa:bar'.codeUnits)}',
      },
      body: {'grant_type': 'client_credentials'},
    );

    print('Response: ${response.body}');
    expectInvalidClient(response);
  });

  test('force correct secret', () async {
    var response = await client.post(
      Uri.parse('/oauth2/token'),
      headers: {
        'Authorization': 'Basic ${base64Url.encode('foo:bara'.codeUnits)}',
      },
      body: {'grant_type': 'client_credentials'},
    );

    print('Response: ${response.body}');
    expectInvalidClient(response);
  });
}

const _dollarClient = PseudoApplication('dollar', r'a$b:c', 'http://foo.bar');

class _AuthorizationServer
    extends AuthorizationServer<PseudoApplication, PseudoUser> {
  @override
  PseudoApplication? findClient(String? clientId) {
    return switch (clientId) {
      'foo' => pseudoApplication,
      'dollar' => _dollarClient,
      _ => null,
    };
  }

  @override
  Future<bool> verifyClient(
    PseudoApplication client,
    String? clientSecret,
  ) async {
    return client.secret == clientSecret;
  }

  @override
  Future<AuthorizationTokenResponse> clientCredentialsGrant(
    PseudoApplication? client,
    RequestContext req,
    ResponseContext res,
  ) async {
    return AuthorizationTokenResponse('foo');
  }
}
