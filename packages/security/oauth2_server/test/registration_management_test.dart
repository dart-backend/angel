import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_oauth2_server/angel3_oauth2_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'common.dart';

final _issuer = Uri.parse('https://example.com');

final _metadata = ServerMetadata(
  issuer: _issuer,
  registrationEndpoint: _issuer.resolve('/oauth2/register'),
  grantTypes: ['authorization_code', 'client_credentials'],
  clientAuthMethods: ['client_secret_basic', 'none'],
);

const _web = {
  'redirect_uris': ['https://app.example/cb'],
};

void main() {
  late TestClient client;
  late _Server server;

  Future<TestClient> connect(AuthorizationServer s) {
    var app = Angel();
    var manage = s.registrationManagementEndpoint(_metadata);
    app
      ..post('/oauth2/register', s.registrationEndpoint(_metadata))
      ..get('/oauth2/register/:client_id', manage)
      ..put('/oauth2/register/:client_id', manage)
      ..delete('/oauth2/register/:client_id', manage)
      ..post('/oauth2/token', s.tokenEndpoint);
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

  Future<Map> register(Map body) async {
    var response = await client.post(
      Uri.parse('/oauth2/register'),
      headers: {'content-type': 'application/json'},
      body: json.encode(body),
    );
    expect(response, hasStatus(201), reason: response.body);
    return json.decode(response.body) as Map;
  }

  Map<String, String> bearer(String token) => {
    'authorization': 'Bearer $token',
  };

  Future<http.Response> read(String id, String token) =>
      client.get(Uri.parse('/oauth2/register/$id'), headers: bearer(token));

  Future<http.Response> update(String id, String token, Map body) => client.put(
    Uri.parse('/oauth2/register/$id'),
    headers: {...bearer(token), 'content-type': 'application/json'},
    body: json.encode(body),
  );

  void expectInvalidToken(http.Response response) {
    expect(response, hasStatus(401), reason: response.body);
    expect(
      response.headers['www-authenticate'],
      startsWith('Bearer realm="oauth2", error="invalid_token"'),
    );
  }

  void expectRefused(http.Response response, String error) {
    expect(response, hasStatus(400), reason: response.body);
    expect(json.decode(response.body), containsPair('error', error));
  }

  test('registration issues a registration access token and URL', () async {
    var json = await register(_web);
    expect((json['registration_access_token'] as String).length, 43);
    expect(
      json['registration_client_uri'],
      'https://example.com/oauth2/register/${json['client_id']}',
    );
  });

  test('a GET reads the registration, of no secret nor token', () async {
    var json = await register({..._web, 'client_name': 'App'});
    var response = await read(
      json['client_id'],
      json['registration_access_token'],
    );
    expect(response, hasStatus(200));
    expect(response.headers['cache-control'], 'no-store');
    var readBack = jsonDecode(response.body) as Map;
    expect(readBack, containsPair('client_name', 'App'));
    expect(readBack, containsPair('client_id', json['client_id']));
    expect(
      readBack,
      containsPair('registration_client_uri', json['registration_client_uri']),
    );
    expect(readBack, isNot(contains('client_secret')));
    expect(readBack, isNot(contains('registration_access_token')));
  });

  group('the registration access token', () {
    test('is required, of a challenge', () async {
      var json = await register(_web);
      var response = await client.get(
        Uri.parse('/oauth2/register/${json['client_id']}'),
      );
      expect(response, hasStatus(401));
      expect(response.headers['www-authenticate'], 'Bearer realm="oauth2"');
    });

    test('must be of the client, which must exist, alike', () async {
      var a = await register(_web);
      var b = await register(_web);
      expectInvalidToken(await read(a['client_id'], 'wrong'));
      expectInvalidToken(
        await read(a['client_id'], b['registration_access_token']),
      );
      expectInvalidToken(await read('nobody', a['registration_access_token']));
    });
  });

  group('a PUT', () {
    test('replaces the registration, of all its metadata', () async {
      var json = await register({
        ..._web,
        'client_name': 'App',
        'logo_uri': 'https://app.example/logo',
      });
      var id = json['client_id'] as String;
      var token = json['registration_access_token'] as String;
      var response = await update(id, token, {
        'client_id': id,
        'redirect_uris': ['https://app.example/new'],
        'client_name': 'Renamed',
      });
      expect(response, hasStatus(200), reason: response.body);
      var updated = jsonDecode(response.body) as Map;
      expect(updated, containsPair('client_name', 'Renamed'));
      // Not given, so no longer registered.
      expect(updated, isNot(contains('logo_uri')));
      expect(
        updated,
        containsPair('redirect_uris', ['https://app.example/new']),
      );
      // Of the same id, time and secret, which it does not give again.
      expect(updated['client_id_issued_at'], json['client_id_issued_at']);
      expect(updated, isNot(contains('client_secret')));
      expect(updated, isNot(contains('registration_access_token')));
      expect(
        jsonDecode((await read(id, token)).body),
        containsPair('client_name', 'Renamed'),
      );
      // The secret still authenticates the client.
      expect(server.secrets[id], json['client_secret']);
    });

    test('must give the client_id of the registration', () async {
      var json = await register(_web);
      var id = json['client_id'] as String;
      var token = json['registration_access_token'] as String;
      expectRefused(
        await update(id, token, {..._web}),
        'invalid_client_metadata',
      );
      expectRefused(
        await update(id, token, {..._web, 'client_id': 'other'}),
        'invalid_client_metadata',
      );
    });

    test('may not give what the server issues', () async {
      var json = await register(_web);
      var id = json['client_id'] as String;
      var token = json['registration_access_token'] as String;
      for (var name in [
        'registration_access_token',
        'registration_client_uri',
        'client_id_issued_at',
        'client_secret_expires_at',
      ]) {
        expectRefused(
          await update(id, token, {..._web, 'client_id': id, name: 'x'}),
          'invalid_client_metadata',
        );
      }
    });

    test('may give the client_secret, which must be the client\'s', () async {
      var json = await register(_web);
      var id = json['client_id'] as String;
      var token = json['registration_access_token'] as String;
      var body = {..._web, 'client_id': id};
      expect(
        await update(id, token, {
          ...body,
          'client_secret': json['client_secret'],
        }),
        hasStatus(200),
      );
      expectRefused(
        await update(id, token, {...body, 'client_secret': 'wrong'}),
        'invalid_client_metadata',
      );
    });

    test('is checked as a registration is', () async {
      var json = await register(_web);
      var id = json['client_id'] as String;
      var token = json['registration_access_token'] as String;
      expectRefused(
        await update(id, token, {
          'client_id': id,
          'redirect_uris': ['http://app.example/cb'],
        }),
        'invalid_redirect_uri',
      );
    });

    test('issues a secret to a client that is no longer public', () async {
      var json = await register({
        ..._web,
        'token_endpoint_auth_method': 'none',
      });
      expect(json, isNot(contains('client_secret')));
      var id = json['client_id'] as String;
      var response = await update(id, json['registration_access_token'], {
        ..._web,
        'client_id': id,
      });
      var secret = jsonDecode(response.body)['client_secret'] as String;
      expect(server.secrets[id], secret);
    });
  });

  test('a DELETE removes the client, which is then unknown', () async {
    var json = await register({
      'grant_types': ['client_credentials'],
    });
    var id = json['client_id'] as String;
    var token = json['registration_access_token'] as String;
    var response = await client.delete(
      Uri.parse('/oauth2/register/$id'),
      headers: bearer(token),
    );
    expect(response, hasStatus(204));
    expect(response.body, isEmpty);
    expectInvalidToken(await read(id, token));
    var credentials = '$id:${json['client_secret']}';
    expect(
      await client.post(
        Uri.parse('/oauth2/token'),
        headers: {
          'authorization': 'Basic ${base64.encode(credentials.codeUnits)}',
        },
        body: {'grant_type': 'client_credentials'},
      ),
      hasStatus(401),
    );
  });

  test('a rotating server issues a new token and secret on update', () async {
    var rotating = await connect(_Server(rotates: true));
    try {
      var created = await rotating.post(
        Uri.parse('/oauth2/register'),
        headers: {'content-type': 'application/json'},
        body: json.encode(_web),
      );
      var registered = jsonDecode(created.body) as Map;
      var id = registered['client_id'] as String;
      var token = registered['registration_access_token'] as String;
      var response = await rotating.put(
        Uri.parse('/oauth2/register/$id'),
        headers: {...bearer(token), 'content-type': 'application/json'},
        body: json.encode({..._web, 'client_id': id}),
      );
      var updated = jsonDecode(response.body) as Map;
      expect(updated['registration_access_token'], isNot(token));
      expect(updated['client_secret'], isNot(registered['client_secret']));
      expectInvalidToken(
        await rotating.get(
          Uri.parse('/oauth2/register/$id'),
          headers: bearer(token),
        ),
      );
      expect(
        await rotating.get(
          Uri.parse('/oauth2/register/$id'),
          headers: bearer(updated['registration_access_token']),
        ),
        hasStatus(200),
      );
    } finally {
      await rotating.close();
    }
  });

  test('updates and deletes are refused by default', () async {
    var other = await connect(_ReadOnlyServer());
    try {
      var created = await other.post(
        Uri.parse('/oauth2/register'),
        headers: {'content-type': 'application/json'},
        body: json.encode(_web),
      );
      var registered = jsonDecode(created.body) as Map;
      var id = registered['client_id'] as String;
      var token = bearer(registered['registration_access_token']);
      expect(
        await other.get(Uri.parse('/oauth2/register/$id'), headers: token),
        hasStatus(200),
      );
      expect(
        await other.put(
          Uri.parse('/oauth2/register/$id'),
          headers: {...token, 'content-type': 'application/json'},
          body: json.encode({..._web, 'client_id': id}),
        ),
        hasStatus(403),
      );
      expect(
        await other.delete(Uri.parse('/oauth2/register/$id'), headers: token),
        hasStatus(403),
      );
    } finally {
      await other.close();
    }
  });

  test('the endpoint requires managesClientRegistrations', () {
    expect(
      () => _NotManaging().registrationManagementEndpoint(_metadata),
      throwsArgumentError,
    );
    for (var endpoint in [
      _Server().registrationManagementEndpoint,
      _Server().registrationEndpoint,
    ]) {
      expect(
        () => endpoint(ServerMetadata(issuer: _issuer)),
        throwsArgumentError,
      );
    }
  });
}

class _NotManaging extends AuthorizationServer<PseudoApplication, PseudoUser> {
  @override
  PseudoApplication? findClient(String? clientId) => null;

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) => false;
}

/// A server of registrations that it reads, but neither updates nor
/// deletes; of their secrets and tokens, as of hashes, which it never gives
/// back.
class _ReadOnlyServer extends _NotManaging {
  final registrations = <String, ClientRegistration>{};
  final secrets = <String, String?>{};
  final tokens = <String, String>{};

  @override
  bool get managesClientRegistrations => true;

  @override
  PseudoApplication? findClient(String? clientId) =>
      registrations.containsKey(clientId)
      ? PseudoApplication(clientId!, secrets[clientId] ?? '', '')
      : null;

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) =>
      client.secret.isEmpty
      ? clientSecret == null
      : client.secret == clientSecret;

  @override
  bool mayRegisterClient(String? initialAccessToken, RequestContext req) =>
      true;

  void store(ClientRegistration registration) {
    var id = registration.clientId;
    registrations[id] = registration;
    if (registration.tokenEndpointAuthMethod == 'none') {
      secrets[id] = null;
    } else if (registration.clientSecret != null) {
      secrets[id] = registration.clientSecret;
    }
    if (registration.registrationAccessToken case var token?) {
      tokens[id] = token;
    }
  }

  @override
  void registerClient(ClientRegistration registration, RequestContext req) =>
      store(registration);

  @override
  ClientRegistration? findRegistration(
    String clientId,
    String registrationAccessToken,
    RequestContext req,
  ) {
    var registration = registrations[clientId];
    if (registration == null || tokens[clientId] != registrationAccessToken) {
      return null;
    }
    // As read back, of no secret nor token.
    return ClientRegistration(
      clientId: registration.clientId,
      clientSecret: null,
      issuedAt: registration.issuedAt,
      redirectUris: registration.redirectUris,
      grantTypes: registration.grantTypes,
      responseTypes: registration.responseTypes,
      tokenEndpointAuthMethod: registration.tokenEndpointAuthMethod,
      scopes: registration.scopes,
      metadata: registration.metadata,
    );
  }

  @override
  AuthorizationTokenResponse clientCredentialsGrant(
    PseudoApplication? client,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) => AuthorizationTokenResponse('token');
}

class _Server extends _ReadOnlyServer {
  final bool rotates;

  _Server({this.rotates = false});

  @override
  bool get rotatesRegistrationAccessToken => rotates;

  @override
  bool get rotatesClientSecretOnUpdate => rotates;

  @override
  void updateClient(
    ClientRegistration current,
    ClientRegistration updated,
    RequestContext req,
  ) => store(updated);

  @override
  void deleteClient(ClientRegistration registration, RequestContext req) {
    var id = registration.clientId;
    registrations.remove(id);
    secrets.remove(id);
    tokens.remove(id);
  }
}
