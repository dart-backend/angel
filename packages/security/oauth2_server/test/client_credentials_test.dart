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
    expect(response.headers['www-authenticate'], 'Basic realm="oauth2"');
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

  test('the credentials are percent-decoded, as package:oauth2 encodes '
      'them', () async {
    var response = await withBasic(
      'Basic ${base64.encode(utf8.encode('space:p%40ss%20w%C3%B6rd+'))}',
    );
    expect(response, hasStatus(200));
  });

  test('the scheme is of any case, and the base64 may be unpadded', () async {
    var unpadded = base64.encode('foo:bar'.codeUnits).replaceAll('=', '');
    expect(await withBasic('basic $unpadded'), hasStatus(200));
    expect(await withBasic('BASIC $unpadded'), hasStatus(200));
  });

  group('without an Authorization header', () {
    Future<http.Response> withForm(Map<String, String> body) => client.post(
      Uri.parse('/oauth2/token'),
      body: {'grant_type': 'client_credentials', ...body},
    );

    Future<http.Response> withPassword(
      Map<String, String> body, {
      Map<String, String>? headers,
    }) => client.post(
      Uri.parse('/oauth2/token'),
      headers: headers,
      body: {
        'grant_type': 'password',
        'username': 'u',
        'password': 'p',
        ...body,
      },
    );

    test('a client is authenticated by the form', () async {
      expect(
        await withForm({'client_id': 'foo', 'client_secret': 'bar'}),
        hasStatus(200),
      );
    });

    test('a public client gives its id alone', () async {
      expect(await withPassword({'client_id': 'public'}), hasStatus(200));
    });

    test('an empty secret is no secret', () async {
      expect(
        await withPassword({'client_id': 'public', 'client_secret': ''}),
        hasStatus(200),
      );
      expect(
        await withPassword(
          {},
          headers: {
            'Authorization': 'Basic ${base64.encode('public:'.codeUnits)}',
          },
        ),
        hasStatus(200),
      );
    });

    test('a public client may not use the client credentials grant', () async {
      for (var body in [
        {'client_id': 'public'},
        {'client_id': 'public', 'client_secret': ''},
      ]) {
        var response = await withForm(body);
        expect(response, hasStatus(400));
        expect(
          json.decode(response.body),
          containsPair('error', 'unauthorized_client'),
        );
      }
    });

    test('a client with a secret must give it', () async {
      var response = await withForm({'client_id': 'foo'});
      expect(response, hasStatus(401));
      expect(response.headers, isNot(contains('www-authenticate')));
      expect(
        json.decode(response.body),
        containsPair('error', 'invalid_client'),
      );
    });

    test('no credentials at all are a challenge of Basic', () async {
      expectInvalidClient(await withForm({}));
    });

    test('an unknown grant type is unsupported_grant_type, before the client '
        'is authenticated', () async {
      var response = await client.post(
        Uri.parse('/oauth2/token'),
        body: {'grant_type': 'nope'},
      );
      expect(response, hasStatus(400));
      expect(
        json.decode(response.body),
        containsPair('error', 'unsupported_grant_type'),
      );
    });

    test('a device code request the server does not implement is '
        'invalid_request, of a missing grant type', () async {
      for (var body in [
        {'client_id': 'foo', 'state': 'xyz'},
        {'client_id': 'foo', 'grant_type': '', 'state': 'xyz'},
      ]) {
        var response = await client.post(
          Uri.parse('/oauth2/token'),
          body: body,
        );
        expect(response, hasStatus(400));
        expect(
          json.decode(response.body),
          containsPair('error', 'invalid_request'),
        );
      }
    });
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
        'grant_type': 'refresh_token',
        'refresh_token': 'r',
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
const _spaceClient = PseudoApplication('space', 'p@ss wörd+', 'http://foo.bar');

/// A client without a secret.
const _publicClient = PseudoApplication('public', '', 'http://foo.bar');

class _AuthorizationServer
    extends AuthorizationServer<PseudoApplication, PseudoUser> {
  @override
  PseudoApplication? findClient(String? clientId) {
    return switch (clientId) {
      'foo' => pseudoApplication,
      'dollar' => _dollarClient,
      'space' => _spaceClient,
      'public' => _publicClient,
      _ => null,
    };
  }

  @override
  Future<bool> verifyClient(
    PseudoApplication client,
    String? clientSecret,
  ) async {
    // A public client gives no secret.
    return identical(client, _publicClient)
        ? clientSecret == null
        : client.secret == clientSecret;
  }

  @override
  Future<AuthorizationTokenResponse> clientCredentialsGrant(
    PseudoApplication? client,
    RequestContext req,
    ResponseContext res,
  ) async {
    return AuthorizationTokenResponse('foo');
  }

  @override
  Future<AuthorizationTokenResponse> resourceOwnerPasswordCredentialsGrant(
    PseudoApplication? client,
    String? username,
    String? password,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) async {
    return AuthorizationTokenResponse('bar');
  }
}
