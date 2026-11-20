import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
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

  test('a secret of escapes that are not UTF-8 is kept, not a 500', () async {
    expect(
      await withBasic('Basic ${base64.encode(utf8.encode('raw:a%FFb'))}'),
      hasStatus(200),
    );
    expectInvalidClient(
      await withBasic('Basic ${base64.encode(utf8.encode('foo:a%FFb'))}'),
    );
  });

  test('a Basic header may have leading spaces', () async {
    expect(
      await withBasic('  Basic ${base64.encode('foo:bar'.codeUnits)}'),
      hasStatus(200),
    );
  });

  test('an empty client id is invalid_client', () async {
    expectInvalidClient(
      await withBasic('Basic ${base64.encode(utf8.encode(':bar'))}'),
    );
  });

  test('a header of another scheme is ignored for the form', () async {
    var response = await client.post(
      Uri.parse('/oauth2/token'),
      headers: {'Authorization': 'Bearer of-a-proxy'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': 'foo',
        'client_secret': 'bar',
      },
    );
    expect(response, hasStatus(200));
  });

  group('over dart:io, whose headers may have several values', () {
    late AngelHttp http;

    setUp(() async {
      var app = Angel();
      app.post('/oauth2/token', _AuthorizationServer().tokenEndpoint);
      app.errorHandler = (e, req, res) async {
        res.statusCode = e.statusCode;
        res.json(e.toJson());
      };
      http = AngelHttp(app);
      await http.startServer('127.0.0.1', 0);
    });

    tearDown(() => http.close());

    /// The status and body of a client credentials grant of the
    /// `Authorization` headers [values], each on a line of its own, as a
    /// proxy may send them, which `HttpClient` would join; of HTTP/1.0, so
    /// that the response is not chunked.
    Future<(int, Map)> post(List<String> values) async {
      var socket = await Socket.connect(http.uri.host, http.uri.port);
      try {
        var form = 'grant_type=client_credentials';
        socket.write(
          'POST /oauth2/token HTTP/1.0\r\n'
          'Host: ${http.uri.host}\r\n'
          '${[for (var value in values) 'Authorization: $value\r\n'].join()}'
          'Content-Type: application/x-www-form-urlencoded\r\n'
          'Content-Length: ${form.length}\r\n'
          'Connection: close\r\n'
          '\r\n'
          '$form',
        );
        var response = await utf8.decoder.bind(socket).join();
        var status = int.parse(response.split(' ')[1]);
        var body = response.substring(response.indexOf('{'));
        return (status, json.decode(body) as Map);
      } finally {
        socket.destroy();
      }
    }

    var basic = 'Basic ${base64.encode('foo:bar'.codeUnits)}';

    test('a Basic header is read beside one of another scheme', () async {
      var (status, body) = await post(['Bearer of-a-proxy', basic]);
      expect(status, 200, reason: '$body');
    });

    test('a Basic header joined with one of another scheme is read, as the '
        'shelf driver joins them', () async {
      var (status, body) = await post(['Digest a="1", b="2",$basic']);
      expect(status, 200, reason: '$body');
    });

    test('two Basic headers joined in one value are invalid_request', () async {
      var (status, body) = await post(['$basic,$basic']);
      expect(status, 400);
      expect(body, containsPair('error', 'invalid_request'));
    });

    test('two Basic headers are invalid_request, not a 500', () async {
      var (status, body) = await post([basic, basic]);
      expect(status, 400);
      expect(body, containsPair('error', 'invalid_request'));
    });
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

    test('a header of another scheme is not taken for credentials', () async {
      var response = await client.post(
        Uri.parse('/oauth2/token'),
        headers: {'Authorization': 'Bearer of-a-proxy'},
        body: {'grant_type': 'client_credentials'},
      );
      expectInvalidClient(response);
      expect(response.body, contains('No client credentials'));
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
        {'client_id': 'foo', 'client_secret': 'bar', 'state': 'xyz'},
        {
          'client_id': 'foo',
          'client_secret': 'bar',
          'grant_type': '',
          'state': 'xyz',
        },
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

/// A client of a secret that is not valid percent-encoding.
const _rawClient = PseudoApplication('raw', 'a%FFb', 'http://foo.bar');

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
      'raw' => _rawClient,
      // A lenient lookup, which an empty id must not reach.
      '' => pseudoApplication,
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
