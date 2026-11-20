import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:test/test.dart';

import 'common.dart';

final _issuer = Uri.parse('https://example.com');

Uri _url(String path) => _issuer.replace(path: path);

void main() {
  test('the endpoints, and what the server supports', () {
    var metadata = ServerMetadata(
      issuer: _issuer,
      authorizationEndpoint: _url('/oauth2/authorize'),
      tokenEndpoint: _url('/oauth2/token'),
      deviceAuthorizationEndpoint: _url('/oauth2/device'),
      revocationEndpoint: _url('/oauth2/revoke'),
      responseTypes: ['code', 'token'],
      grantTypes: ['authorization_code', 'implicit', 'refresh_token'],
      clientAuthMethods: ['client_secret_basic', 'client_secret_post', 'none'],
      scopes: ['read', 'write'],
      serviceDocumentation: _url('/docs'),
    );
    expect(_Server().metadataOf(metadata), {
      'issuer': 'https://example.com',
      'authorization_endpoint': 'https://example.com/oauth2/authorize',
      'token_endpoint': 'https://example.com/oauth2/token',
      'device_authorization_endpoint': 'https://example.com/oauth2/device',
      'revocation_endpoint': 'https://example.com/oauth2/revoke',
      'response_types_supported': ['code', 'token'],
      'response_modes_supported': ['query', 'fragment'],
      'grant_types_supported': [
        'authorization_code',
        'implicit',
        'refresh_token',
        'urn:ietf:params:oauth:grant-type:device_code',
        'urn:example:custom',
      ],
      'code_challenge_methods_supported': ['S256'],
      'token_endpoint_auth_methods_supported': [
        'client_secret_basic',
        'client_secret_post',
        'none',
      ],
      'revocation_endpoint_auth_methods_supported': [
        'client_secret_basic',
        'client_secret_post',
        'none',
      ],
      'scopes_supported': ['read', 'write'],
      'service_documentation': 'https://example.com/docs',
    });
  });

  test('only what is given, by default', () {
    expect(_Server().metadataOf(ServerMetadata(issuer: _issuer)), {
      'issuer': 'https://example.com',
      'response_types_supported': ['code'],
      'response_modes_supported': ['query'],
      'grant_types_supported': ['authorization_code', 'urn:example:custom'],
      'code_challenge_methods_supported': ['S256'],
    });
  });

  test('implicit, of the token response type', () {
    var json = _Server().metadataOf(
      ServerMetadata(issuer: _issuer, responseTypes: ['code', 'token']),
    );
    expect(json['grant_types_supported'], contains('implicit'));
  });

  test('plain PKCE, if the server allows it', () {
    var json = _Server(allowsPlain: true)
        .metadataOf(ServerMetadata(issuer: _issuer));
    expect(json['code_challenge_methods_supported'], ['S256', 'plain']);
  });

  test('extra metadata is added last', () {
    var json = _Server().metadataOf(
      ServerMetadata(
        issuer: _issuer,
        extra: {
          'introspection_endpoint': 'https://example.com/introspect',
          'response_modes_supported': ['query', 'form_post'],
        },
      ),
    );
    expect(json['introspection_endpoint'], 'https://example.com/introspect');
    expect(json['response_modes_supported'], ['query', 'form_post']);
  });

  group('the issuer', () {
    test('must be https, or http of localhost', () {
      expect(
        () => ServerMetadata(issuer: Uri.parse('http://example.com')),
        throwsArgumentError,
      );
      expect(
        () => ServerMetadata(issuer: Uri.parse('/relative')),
        throwsArgumentError,
      );
      ServerMetadata(issuer: Uri.parse('http://localhost:3000'));
      ServerMetadata(issuer: Uri.parse('http://[::1]:3000'));
    });

    test('must have no query nor fragment', () {
      for (var issuer in ['https://example.com?a=b', 'https://example.com#a']) {
        expect(
          () => ServerMetadata(issuer: Uri.parse(issuer)),
          throwsArgumentError,
        );
      }
    });

    test('gives the well-known path, after its own', () {
      expect(
        ServerMetadata(issuer: _issuer).wellKnownPath,
        '/.well-known/oauth-authorization-server',
      );
      expect(
        ServerMetadata(issuer: Uri.parse('https://example.com/')).wellKnownPath,
        '/.well-known/oauth-authorization-server',
      );
      expect(
        ServerMetadata(issuer: Uri.parse('https://example.com/tenant1/'))
            .wellKnownPath,
        '/.well-known/oauth-authorization-server/tenant1',
      );
    });
  });

  test('is served as JSON at the well-known path', () async {
    var metadata = ServerMetadata(
      issuer: _issuer,
      tokenEndpoint: _url('/oauth2/token'),
    );
    var app = Angel();
    app.get(metadata.wellKnownPath, _Server().metadataEndpoint(metadata));
    var client = await connectTo(app);
    try {
      var response = await client.get(
        Uri.parse('/.well-known/oauth-authorization-server'),
      );
      expect(response, hasStatus(200));
      expect(response.headers['content-type'], contains('application/json'));
      expect(
        json.decode(response.body),
        containsPair('token_endpoint', 'https://example.com/oauth2/token'),
      );
    } finally {
      await client.close();
    }
  });
}

class _Server extends AuthorizationServer<PseudoApplication, PseudoUser> {
  final bool allowsPlain;

  _Server({this.allowsPlain = false});

  @override
  bool get allowsPlainPkce => allowsPlain;

  @override
  Map<String, ExtensionGrant> get extensionGrants => {
    'urn:example:custom': (req, res) => AuthorizationTokenResponse('t'),
  };

  @override
  PseudoApplication? findClient(String? clientId) => pseudoApplication;

  @override
  bool verifyClient(PseudoApplication client, String? clientSecret) => true;
}
