import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'common.dart';

final _issuer = Uri.parse('https://example.com');

final _metadata = ServerMetadata(
  issuer: _issuer,
  registrationEndpoint: _issuer.resolve('/oauth2/register'),
  responseTypes: ['code'],
  grantTypes: ['authorization_code', 'refresh_token', 'client_credentials'],
  clientAuthMethods: ['client_secret_basic', 'client_secret_post', 'none'],
  scopes: ['read', 'write'],
);

void main() {
  late TestClient client;
  late _Server server;

  setUp(() async {
    server = _Server();
    var app = Angel();
    app
      ..post('/oauth2/register', server.registrationEndpoint(_metadata))
      ..post('/oauth2/token', server.tokenEndpoint);
    app.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    client = await connectTo(app);
  });

  tearDown(() => client.close());

  Future<http.Response> register(
    Object? body, {
    String? token = 'initial',
    String contentType = 'application/json',
  }) => client.post(
    Uri.parse('/oauth2/register'),
    headers: {
      'content-type': contentType,
      if (token != null) 'authorization': 'Bearer $token',
    },
    body: body is String ? body : json.encode(body),
  );

  Future<Map> registered(Object? body) async {
    var response = await register(body);
    expect(response, hasStatus(201), reason: response.body);
    expect(response.headers['cache-control'], 'no-store');
    return json.decode(response.body) as Map;
  }

  void expectRefused(http.Response response, String error) {
    expect(response, hasStatus(400), reason: response.body);
    expect(json.decode(response.body), containsPair('error', error));
  }

  const web = {
    'redirect_uris': ['https://app.example/cb'],
  };

  test('a confidential client is issued an id and a secret', () async {
    var json = await registered({...web, 'client_name': 'App'});
    expect(json['client_id'], isA<String>());
    expect((json['client_secret'] as String).length, greaterThan(40));
    expect(json['client_secret_expires_at'], 0);
    expect(json['client_id_issued_at'], isA<int>());
    expect(json, containsPair('client_name', 'App'));
    // Of a server that does not manage registrations.
    expect(json, isNot(contains('registration_access_token')));
    expect(json, isNot(contains('registration_client_uri')));
    expect(json, containsPair('grant_types', ['authorization_code']));
    expect(json, containsPair('response_types', ['code']));
    expect(
      json,
      containsPair('token_endpoint_auth_method', 'client_secret_basic'),
    );
    expect(
      server.clients[json['client_id']]!.clientSecret,
      json['client_secret'],
    );
  });

  test('a registered client authenticates at the token endpoint', () async {
    var json = await registered({
      'grant_types': ['client_credentials'],
      'scope': 'read',
    });
    // Of no redirect grant, of no response types, nor redirect URIs.
    expect(json, containsPair('response_types', []));
    var credentials = '${json['client_id']}:${json['client_secret']}';
    var response = await client.post(
      Uri.parse('/oauth2/token'),
      headers: {
        'authorization': 'Basic ${base64.encode(credentials.codeUnits)}',
      },
      body: {'grant_type': 'client_credentials'},
    );
    expect(response, hasStatus(200), reason: response.body);
  });

  test('a public client is issued no secret', () async {
    var json = await registered({...web, 'token_endpoint_auth_method': 'none'});
    expect(json, isNot(contains('client_secret')));
    expect(json, isNot(contains('client_secret_expires_at')));
    expectRefused(
      await register({
        'grant_types': ['client_credentials'],
        'token_endpoint_auth_method': 'none',
      }),
      'invalid_client_metadata',
    );
  });

  test(
    'what the server issues, or does not verify, is not registered',
    () async {
      var json = await registered({
        ...web,
        'client_id': 'chosen',
        'client_secret': 'chosen',
        'software_statement': 'eyJ...',
        'x_extension': 42,
      });
      expect(json['client_id'], isNot('chosen'));
      expect(json['client_secret'], isNot('chosen'));
      expect(json, isNot(contains('software_statement')));
      expect(json, containsPair('x_extension', 42));
    },
  );

  test('registerClient may change the metadata, or refuse it', () async {
    expect(
      await registered({...web, 'client_name': 'rename me'}),
      containsPair('client_name', 'renamed'),
    );
    expectRefused(
      await register({...web, 'client_name': 'refuse me'}),
      'invalid_client_metadata',
    );
  });

  test('the response gives what is checked of the fields, not the metadata '
      'that registerClient changes', () async {
    var json = await registered({...web, 'client_name': 'widen me'});
    expect(json, containsPair('grant_types', ['authorization_code']));
    expect(json, containsPair('redirect_uris', ['https://app.example/cb']));
  });

  group('the initial access token', () {
    test('is required, of a challenge', () async {
      var response = await register(web, token: null);
      expect(response, hasStatus(401));
      expect(response.headers['www-authenticate'], 'Bearer realm="oauth2"');
    });

    test('must be one that mayRegisterClient accepts', () async {
      var response = await register(web, token: 'wrong');
      expect(response, hasStatus(401));
      expect(
        response.headers['www-authenticate'],
        startsWith('Bearer realm="oauth2", error="invalid_token"'),
      );
      expect(server.clients, isEmpty);
    });

    test('is refused by default', () async {
      var app = Angel()
        ..post('/r', _DefaultServer().registrationEndpoint(_metadata));
      app.errorHandler = (e, req, res) async {
        res.statusCode = e.statusCode;
        res.json(e.toJson());
      };
      var other = await connectTo(app);
      try {
        var response = await other.post(
          Uri.parse('/r'),
          headers: {'content-type': 'application/json'},
          body: json.encode(web),
        );
        expect(response, hasStatus(401));
      } finally {
        await other.close();
      }
    });
  });

  group('the redirect URIs', () {
    test('are required of the authorization endpoint', () async {
      expectRefused(await register({}), 'invalid_redirect_uri');
    });

    test('are https, http of localhost, or of a native app', () async {
      await registered({
        'redirect_uris': [
          'https://app.example/cb?a=b',
          'http://localhost:8080/cb',
          'http://127.0.0.1/cb',
          'http://[::1]:8080/cb',
          'com.example.app:/oauth2redirect',
        ],
      });
      for (var uri in [
        'http://app.example/cb',
        'https://app.example/cb#fragment',
        '/relative',
        'javascript:alert(1)',
        'vbscript:msgbox(1)',
        'blob:https://app.example/1',
        'myapp:/cb',
        'https:///cb',
      ]) {
        expectRefused(
          await register({
            'redirect_uris': [uri],
          }),
          'invalid_redirect_uri',
        );
      }
    });
  });

  test('an implicit client registers, of a server of the token response '
      'type', () async {
    var implicitServer = _Server();
    var app = Angel()
      ..post(
        '/oauth2/register',
        implicitServer.registrationEndpoint(
          ServerMetadata(
            issuer: _issuer,
            registrationEndpoint: _issuer.resolve('/oauth2/register'),
            responseTypes: ['code', 'token'],
            clientAuthMethods: ['none'],
          ),
        ),
      );
    app.errorHandler = (e, req, res) async {
      res.statusCode = e.statusCode;
      res.json(e.toJson());
    };
    var other = await connectTo(app);
    try {
      for (var body in [
        {
          'grant_types': ['implicit'],
        },
        {
          'response_types': ['token'],
        },
      ]) {
        var response = await other.post(
          Uri.parse('/oauth2/register'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer initial',
          },
          body: json.encode({
            ...web,
            ...body,
            'token_endpoint_auth_method': 'none',
          }),
        );
        expect(response, hasStatus(201), reason: response.body);
      }
    } finally {
      await other.close();
    }
  });

  group('the metadata', () {
    test('must be a JSON object', () async {
      expectRefused(await register('[]'), 'invalid_client_metadata');
      expectRefused(await register('{'), 'invalid_client_metadata');
      expectRefused(
        await register('a=b', contentType: 'application/x-www-form-urlencoded'),
        'invalid_client_metadata',
      );
    });

    test('must be of what the server supports', () async {
      for (var body in [
        {
          ...web,
          'grant_types': ['authorization_code', 'password'],
        },
        {...web, 'token_endpoint_auth_method': 'private_key_jwt'},
        {...web, 'scope': 'read admin'},
        {
          ...web,
          'response_types': ['code', 'token'],
          'grant_types': ['authorization_code', 'implicit'],
        },
      ]) {
        expectRefused(await register(body), 'invalid_client_metadata');
      }
    });

    test('must have its grant and response types of each other', () async {
      expectRefused(
        await register({
          ...web,
          'grant_types': ['refresh_token'],
          'response_types': ['code'],
        }),
        'invalid_client_metadata',
      );
    });

    test('must be of the types of RFC 7591', () async {
      for (var body in [
        {...web, 'client_name': 42},
        {...web, 'grant_types': 'authorization_code'},
        {
          ...web,
          'contacts': [1],
        },
        {...web, 'logo_uri': 'ftp://logo'},
        {...web, 'jwks_uri': 'https://keys', 'jwks': {}},
      ]) {
        expectRefused(await register(body), 'invalid_client_metadata');
      }
    });
  });

  test('the server metadata gives the endpoint', () {
    expect(
      _Server().metadataOf(_metadata),
      containsPair(
        'registration_endpoint',
        'https://example.com/oauth2/register',
      ),
    );
  });
}

class _DefaultServer
    extends AuthorizationServer<PseudoApplication, PseudoUser> {
  @override
  PseudoApplication? findClient(String? clientId) => null;

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) => false;
}

class _Server extends _DefaultServer {
  final clients = <String, ClientRegistration>{};

  @override
  PseudoApplication? findClient(String? clientId) {
    var registration = clients[clientId];
    if (registration == null) return null;
    return PseudoApplication(
      registration.clientId,
      registration.clientSecret ?? '',
      registration.redirectUris.firstOrNull?.toString() ?? '',
    );
  }

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) =>
      client.secret.isEmpty
      ? clientSecret == null
      : client.secret == clientSecret;

  @override
  bool mayRegisterClient(String? initialAccessToken, RequestContext req) =>
      initialAccessToken == 'initial';

  @override
  void registerClient(ClientRegistration registration, RequestContext req) {
    switch (registration.metadata['client_name']) {
      case 'rename me':
        registration.metadata['client_name'] = 'renamed';
      case 'widen me':
        registration.metadata
          ..['grant_types'] = ['client_credentials']
          ..['redirect_uris'] = ['https://elsewhere.example/cb'];
      case 'refuse me':
        throw AuthorizationException(
          ErrorResponse(
            ErrorResponse.invalidClientMetadata,
            'This name is not allowed.',
            null,
          ),
        );
    }
    clients[registration.clientId] = registration;
  }

  @override
  AuthorizationTokenResponse clientCredentialsGrant(
    PseudoApplication? client,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) => AuthorizationTokenResponse('token');
}
