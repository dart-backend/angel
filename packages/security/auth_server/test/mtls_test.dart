import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _fixtures = 'test/fixtures/mtls';

/// The `x5t#S256` of the client certificates, of `openssl x509 -outform
/// der | openssl dgst -sha256 -binary`, base64url without padding.
const _clientThumbprint = 'mwxD5dp57sAA5w2M-rfbh9U_ajKMZHOJs1PM6NHy8ZE';
const _rogueThumbprint = 'C3QdaXjEbbhR0wi0IvilGhTCSZkRa2z0J7xfJ1_pmJU';

final _clientPem = File('$_fixtures/client.pem').readAsStringSync();
final _roguePem = File('$_fixtures/rogue.pem').readAsStringSync();

final _issuer = Uri.parse('https://example.com');

ServerMetadata _metadataOf({bool bound = true}) => ServerMetadata(
  issuer: _issuer,
  tokenEndpoint: _issuer.resolve('/oauth2/token'),
  introspectionEndpoint: _issuer.resolve('/oauth2/introspect'),
  registrationEndpoint: _issuer.resolve('/oauth2/register'),
  responseTypes: ['code'],
  grantTypes: ['authorization_code', 'client_credentials'],
  clientAuthMethods: [
    'client_secret_basic',
    'none',
    'tls_client_auth',
    'self_signed_tls_client_auth',
  ],
  tlsClientCertificateBoundAccessTokens: bound,
  mtlsEndpointAliases: bound
      ? {'token_endpoint': Uri.parse('https://mtls.example.com/oauth2/token')}
      : null,
);

class _Client {
  final String id;

  /// `''` of a client of no secret: public, or of mutual TLS.
  final String secret;

  /// The thumbprint of the certificate of a client of mutual TLS.
  final String? thumbprint;

  const _Client(this.id, {this.secret = '', this.thumbprint});
}

const _clients = {
  'mtls-app': _Client('mtls-app', thumbprint: _clientThumbprint),
  'public-app': _Client('public-app'),
  'secret-app': _Client('secret-app', secret: 'bar'),
};

/// A server of the clients above, which reads the client certificate of
/// the `x-client-cert` header, as of a reverse proxy, if [ofHeader].
class _Server extends AuthorizationServer<_Client, String> {
  final bool ofHeader;
  final List<String> verified = [];
  final Map<String, ClientRegistration> registered = {};
  final List<ClientRegistration> updates = [];

  _Server({this.ofHeader = true});

  @override
  FutureOr<_Client>? findClient(String? clientId) => _clients[clientId];

  @override
  FutureOr<bool> verifyClient(_Client client, String? clientSecret) {
    // A client of mutual TLS is not authenticated of its id alone.
    if (client.thumbprint != null) return false;
    if (client.secret.isEmpty) return clientSecret == null;
    return client.secret == clientSecret;
  }

  @override
  FutureOr<ClientCertificate?> clientCertificateOf(RequestContext req) {
    if (!ofHeader) return super.clientCertificateOf(req);
    var pem = req.headers?.value('x-client-cert');
    return pem == null
        ? null
        : ClientCertificate.fromPem(Uri.decodeComponent(pem));
  }

  @override
  FutureOr<bool> verifyClientCertificate(
    _Client client,
    ClientCertificate certificate,
    RequestContext req,
  ) {
    verified.add(client.id);
    return client.thumbprint != null &&
        client.thumbprint == certificate.thumbprint;
  }

  @override
  Future<AuthorizationTokenResponse> clientCredentialsGrant(
    _Client? client,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) async {
    // Bound to the certificate of the request, if any (RFC 8705 §3).
    var certificate = await clientCertificateOf(req);
    return AuthorizationTokenResponse(
      certificate == null ? 'unbound' : 'bound.${certificate.thumbprint}',
    );
  }

  @override
  FutureOr<AccessToken<_Client, String>?> findAccessToken(
    String token,
    RequestContext req,
  ) {
    if (token == 'unbound') {
      return const AccessToken(scopes: ['read']);
    }
    if (token.startsWith('bound.')) {
      return AccessToken(
        scopes: const ['read'],
        certificateThumbprint: token.substring('bound.'.length),
      );
    }
    return null;
  }

  @override
  FutureOr<bool> mayIntrospect(_Client caller, RequestContext req) => true;

  @override
  FutureOr<bool> mayRegisterClient(
    String? initialAccessToken,
    RequestContext req,
  ) => true;

  @override
  FutureOr<void> registerClient(
    ClientRegistration registration,
    RequestContext req,
  ) => registered[registration.clientId] = registration;

  @override
  bool get managesClientRegistrations => true;

  @override
  FutureOr<ClientRegistration?> findRegistration(
    String clientId,
    String registrationAccessToken,
    RequestContext req,
  ) => registered[clientId]?.copyWith(
    clientSecret: null,
    registrationAccessToken: null,
  );

  @override
  FutureOr<void> updateClient(
    ClientRegistration current,
    ClientRegistration updated,
    RequestContext req,
  ) {
    updates.add(updated);
  }
}

Angel _appOf(_Server server, ServerMetadata metadata) {
  var app = Angel();
  app
    ..post('/oauth2/token', server.tokenEndpoint)
    ..post('/oauth2/introspect', server.introspectionEndpoint)
    ..post('/oauth2/register', server.registrationEndpoint(metadata))
    ..put(
      '/oauth2/register/:client_id',
      server.registrationManagementEndpoint(metadata),
    )
    ..get(
      '/resource',
      chain([
        server.requireToken(scopes: ['read']),
        (req, res) => 'ok',
      ]),
    )
    ..get(metadata.wellKnownPath, server.metadataEndpoint(metadata));
  app.errorHandler = (e, req, res) async {
    res.statusCode = e.statusCode;
    res.json(e.toJson());
  };
  return app;
}

void main() {
  group('ClientCertificate', () {
    test('has the x5t#S256 thumbprint of its DER', () {
      expect(
        ClientCertificate.fromPem(_clientPem).thumbprint,
        _clientThumbprint,
      );
      expect(ClientCertificate.fromPem(_roguePem).thumbprint, _rogueThumbprint);
    });

    test('of a PEM has no subject', () {
      expect(ClientCertificate.fromPem(_clientPem).subject, isNull);
    });

    test('refuses a text of no certificate', () {
      expect(
        () => ClientCertificate.fromPem('not a certificate'),
        throwsFormatException,
      );
    });
  });

  group('of a client certificate', () {
    late _Server server;
    late TestClient client;

    setUp(() async {
      server = _Server();
      client = await connectTo(_appOf(server, _metadataOf()));
    });

    tearDown(() => client.close());

    Map<String, String> certificateHeader(String pem) => {
      'x-client-cert': Uri.encodeComponent(pem),
    };

    Future<http.Response> token(
      String clientId, {
      String? pem,
      Map<String, String> extra = const {},
    }) => client.post(
      Uri.parse('/oauth2/token'),
      headers: {if (pem != null) ...certificateHeader(pem)},
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        ...extra,
      },
    );

    test('a client authenticates by its certificate', () async {
      var response = await token('mtls-app', pem: _clientPem);
      expect(response, hasStatus(200), reason: response.body);
      expect(
        json.decode(response.body)['access_token'],
        'bound.$_clientThumbprint',
      );
      expect(server.verified, ['mtls-app']);
    });

    test('a client of mutual TLS without its certificate is refused', () async {
      var response = await token('mtls-app');
      expect(response, hasStatus(401));
      expect(json.decode(response.body)['error'], 'invalid_client');
      expect(server.verified, isEmpty);
    });

    test('a client of mutual TLS of another certificate is refused', () async {
      var response = await token('mtls-app', pem: _roguePem);
      expect(response, hasStatus(401));
      expect(json.decode(response.body)['error'], 'invalid_client');
    });

    test('a public client that presents a certificate stays public', () async {
      var response = await token('public-app', pem: _clientPem);
      expect(response, hasStatus(400));
      expect(json.decode(response.body)['error'], 'unauthorized_client');
      expect(server.verified, ['public-app']);
    });

    test('a client of a secret is not asked of its certificate', () async {
      var response = await token(
        'secret-app',
        pem: _clientPem,
        extra: {'client_secret': 'bar'},
      );
      expect(response, hasStatus(200), reason: response.body);
      expect(server.verified, isEmpty);
    });

    test('a client of mutual TLS may introspect, and sees the cnf', () async {
      var response = await client.post(
        Uri.parse('/oauth2/introspect'),
        headers: certificateHeader(_clientPem),
        body: {'client_id': 'mtls-app', 'token': 'bound.$_clientThumbprint'},
      );
      expect(response, hasStatus(200), reason: response.body);
      var body = json.decode(response.body) as Map;
      expect(body['active'], isTrue);
      expect(body['cnf'], {'x5t#S256': _clientThumbprint});
    });

    test('an unbound token has no cnf', () async {
      var response = await client.post(
        Uri.parse('/oauth2/introspect'),
        headers: certificateHeader(_clientPem),
        body: {'client_id': 'mtls-app', 'token': 'unbound'},
      );
      var body = json.decode(response.body) as Map;
      expect(body['active'], isTrue);
      expect(body.containsKey('cnf'), isFalse);
    });

    group('requireToken', () {
      Future<http.Response> resource(String token, {String? pem}) => client.get(
        Uri.parse('/resource'),
        headers: {
          'authorization': 'Bearer $token',
          if (pem != null) ...certificateHeader(pem),
        },
      );

      test('accepts a bound token of its certificate', () async {
        var response = await resource(
          'bound.$_clientThumbprint',
          pem: _clientPem,
        );
        expect(response, hasStatus(200), reason: response.body);
      });

      test('refuses a bound token without its certificate', () async {
        var response = await resource('bound.$_clientThumbprint');
        expect(response, hasStatus(401));
        expect(json.decode(response.body)['error'], 'invalid_token');
        expect(
          response.headers['www-authenticate'],
          contains('error="invalid_token"'),
        );
      });

      test('refuses a bound token of another certificate', () async {
        var response = await resource(
          'bound.$_clientThumbprint',
          pem: _roguePem,
        );
        expect(response, hasStatus(401));
        expect(json.decode(response.body)['error'], 'invalid_token');
      });

      test('accepts an unbound token without a certificate', () async {
        var response = await resource('unbound');
        expect(response, hasStatus(200), reason: response.body);
      });
    });

    group('registration', () {
      Future<http.Response> register(Map<String, dynamic> body) => client.post(
        Uri.parse('/oauth2/register'),
        headers: {'content-type': 'application/json'},
        body: json.encode({
          'grant_types': ['client_credentials'],
          ...body,
        }),
      );

      Future<String> refused(Map<String, dynamic> body) async {
        var response = await register(body);
        expect(response, hasStatus(400), reason: response.body);
        var error = json.decode(response.body) as Map;
        expect(error['error'], 'invalid_client_metadata');
        return error['error_description'] as String;
      }

      test('of tls_client_auth, of one subject, issues no secret', () async {
        var response = await register({
          'token_endpoint_auth_method': 'tls_client_auth',
          'tls_client_auth_subject_dn': 'CN=test-client,O=Angel3',
        });
        expect(response, hasStatus(201), reason: response.body);
        var body = json.decode(response.body) as Map;
        expect(body.containsKey('client_secret'), isFalse);
        expect(body['tls_client_auth_subject_dn'], 'CN=test-client,O=Angel3');
        expect(server.registered.values.single.clientSecret, isNull);
      });

      test('of tls_client_auth, of no subject, is refused', () async {
        expect(
          await refused({'token_endpoint_auth_method': 'tls_client_auth'}),
          contains('exactly one'),
        );
      });

      test('of tls_client_auth, of two subjects, is refused', () async {
        expect(
          await refused({
            'token_endpoint_auth_method': 'tls_client_auth',
            'tls_client_auth_subject_dn': 'CN=test-client',
            'tls_client_auth_san_dns': 'client.example.com',
          }),
          contains('exactly one'),
        );
      });

      test('of a subject that is not a string, is refused', () async {
        expect(
          await refused({
            'token_endpoint_auth_method': 'tls_client_auth',
            'tls_client_auth_san_dns': ['client.example.com'],
          }),
          contains('must be a string'),
        );
      });

      test('of self_signed_tls_client_auth needs its keys', () async {
        expect(
          await refused({
            'token_endpoint_auth_method': 'self_signed_tls_client_auth',
          }),
          contains('"jwks" or "jwks_uri"'),
        );
        var response = await register({
          'token_endpoint_auth_method': 'self_signed_tls_client_auth',
          'jwks': {'keys': []},
        });
        expect(response, hasStatus(201), reason: response.body);
        expect(
          (json.decode(response.body) as Map).containsKey('client_secret'),
          isFalse,
        );
      });

      test('of a jwks that is not an object, is refused', () async {
        expect(
          await refused({
            'token_endpoint_auth_method': 'self_signed_tls_client_auth',
            'jwks': 'keys',
          }),
          contains('JSON Web Key Set'),
        );
      });

      test('of bound tokens', () async {
        var response = await register({
          'token_endpoint_auth_method': 'tls_client_auth',
          'tls_client_auth_san_dns': 'client.example.com',
          'tls_client_certificate_bound_access_tokens': true,
        });
        expect(response, hasStatus(201), reason: response.body);
        expect(
          await refused({
            'token_endpoint_auth_method': 'tls_client_auth',
            'tls_client_auth_san_dns': 'client.example.com',
            'tls_client_certificate_bound_access_tokens': 'yes',
          }),
          contains('must be a boolean'),
        );
      });

      test('an update to tls_client_auth issues no secret', () async {
        var created = json.decode(
          (await register({
            'token_endpoint_auth_method': 'client_secret_basic',
          })).body,
        ) as Map;
        expect(created['client_secret'], isNotNull);
        var id = created['client_id'] as String;
        var response = await client.put(
          Uri.parse('/oauth2/register/$id'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer ${created['registration_access_token']}',
          },
          body: json.encode({
            'client_id': id,
            'grant_types': ['client_credentials'],
            'token_endpoint_auth_method': 'tls_client_auth',
            'tls_client_auth_subject_dn': 'CN=test-client',
          }),
        );
        expect(response, hasStatus(200), reason: response.body);
        expect(server.updates.single.clientSecret, isNull);
        expect(
          server.updates.single.tokenEndpointAuthMethod,
          'tls_client_auth',
        );
      });

      test('an update from tls_client_auth issues a secret', () async {
        var created = json.decode(
          (await register({
            'token_endpoint_auth_method': 'tls_client_auth',
            'tls_client_auth_subject_dn': 'CN=test-client',
          })).body,
        ) as Map;
        var id = created['client_id'] as String;
        var response = await client.put(
          Uri.parse('/oauth2/register/$id'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer ${created['registration_access_token']}',
          },
          body: json.encode({
            'client_id': id,
            'grant_types': ['client_credentials'],
            'token_endpoint_auth_method': 'client_secret_basic',
          }),
        );
        expect(response, hasStatus(200), reason: response.body);
        expect(server.updates.single.clientSecret, isNotNull);
      });
    });

    test('the metadata gives bound tokens and the aliases', () async {
      var response = await client.get(Uri.parse(_metadataOf().wellKnownPath));
      var body = json.decode(response.body) as Map;
      expect(body['tls_client_certificate_bound_access_tokens'], isTrue);
      expect(body['mtls_endpoint_aliases'], {
        'token_endpoint': 'https://mtls.example.com/oauth2/token',
      });
      expect(
        body['token_endpoint_auth_methods_supported'],
        contains('tls_client_auth'),
      );
    });
  });

  group('of a server that does not bind tokens', () {
    late TestClient client;

    setUp(() async {
      client = await connectTo(_appOf(_Server(), _metadataOf(bound: false)));
    });

    tearDown(() => client.close());

    test('its metadata says nothing of them', () async {
      var response = await client.get(
        Uri.parse(_metadataOf(bound: false).wellKnownPath),
      );
      var body = json.decode(response.body) as Map;
      expect(
        body.containsKey('tls_client_certificate_bound_access_tokens'),
        isFalse,
      );
      expect(body.containsKey('mtls_endpoint_aliases'), isFalse);
    });

    test('a client may not register bound tokens', () async {
      var response = await client.post(
        Uri.parse('/oauth2/register'),
        headers: {'content-type': 'application/json'},
        body: json.encode({
          'grant_types': ['client_credentials'],
          'token_endpoint_auth_method': 'tls_client_auth',
          'tls_client_auth_san_dns': 'client.example.com',
          'tls_client_certificate_bound_access_tokens': true,
        }),
      );
      expect(response, hasStatus(400));
      expect(
        json.decode(response.body)['error_description'],
        contains('does not issue certificate-bound access tokens'),
      );
    });
  });

  test('copyWith keeps the metadata of mutual TLS', () {
    var copy = _metadataOf().copyWith(scopes: ['read']);
    expect(copy.tlsClientCertificateBoundAccessTokens, isTrue);
    expect(copy.mtlsEndpointAliases, _metadataOf().mtlsEndpointAliases);
  });

  test('of a real TLS connection, by default', () async {
    var server = _Server(ofHeader: false);
    var context = SecurityContext()
      ..useCertificateChain('$_fixtures/dev.pem')
      ..usePrivateKey('$_fixtures/dev.key', password: 'dartdart')
      ..setClientAuthorities('$_fixtures/ca.pem')
      ..setTrustedCertificates('$_fixtures/ca.pem');
    var driver = AngelHttp.fromSecurityContext(
      _appOf(server, _metadataOf()),
      context,
      requestClientCertificate: true,
    );
    var httpServer = await driver.startServer('127.0.0.1', 0);
    addTearDown(driver.close);

    var clientContext = SecurityContext()
      ..useCertificateChain('$_fixtures/client.pem')
      ..usePrivateKey('$_fixtures/client.key');
    var httpClient = HttpClient(context: clientContext)
      ..badCertificateCallback = (_, _, _) => true;
    addTearDown(() => httpClient.close(force: true));

    var request = await httpClient.postUrl(
      Uri.parse('https://127.0.0.1:${httpServer.port}/oauth2/token'),
    );
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    request.write('grant_type=client_credentials&client_id=mtls-app');
    var response = await request.close();
    var body = json.decode(await response.transform(utf8.decoder).join());
    expect(response.statusCode, 200, reason: '$body');
    expect(body['access_token'], 'bound.$_clientThumbprint');
  });
}
