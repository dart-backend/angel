import 'server.dart';

/// The metadata of an authorization server (RFC 8414), which
/// [AuthorizationServer.metadataEndpoint] serves, so that clients find its
/// endpoints and what it supports.
///
/// Give it the URLs at which the endpoints of the server are routed; the
/// server adds what it knows of itself, such as its PKCE methods.
class ServerMetadata {
  /// The identifier of the server: an `https` URL, of no query nor fragment,
  /// which the tokens it issues may name, and of which [wellKnownPath] is
  /// the path of the metadata. `http` is accepted only for `localhost`.
  final Uri issuer;

  /// The URL of [AuthorizationServer.authorizationEndpoint].
  final Uri? authorizationEndpoint;

  /// The URL of [AuthorizationServer.tokenEndpoint].
  final Uri? tokenEndpoint;

  /// The URL of [AuthorizationServer.deviceAuthorizationEndpoint].
  final Uri? deviceAuthorizationEndpoint;

  /// The URL of [AuthorizationServer.revocationEndpoint].
  final Uri? revocationEndpoint;

  /// The URL of [AuthorizationServer.introspectionEndpoint].
  final Uri? introspectionEndpoint;

  /// The `response_type`s that the authorization endpoint supports: `code`,
  /// and `token`, if the server implements implicit grants.
  final Iterable<String> responseTypes;

  /// The grant types that the server implements, such as `refresh_token`,
  /// `password` or `client_credentials`; the server adds those of its
  /// [AuthorizationServer.extensionGrants], and the device code grant, if
  /// [deviceAuthorizationEndpoint] is given.
  final Iterable<String> grantTypes;

  /// The client authentication methods of the token endpoint, and of the
  /// revocation endpoint: `client_secret_basic`, of the `Authorization:
  /// Basic` header, and `client_secret_post`, of the form; add `none` if
  /// the server has public clients. Those of the introspection endpoint
  /// are these, but `none`, as its callers must have a secret.
  final Iterable<String> clientAuthMethods;

  /// The scopes that the server supports, if it publishes them.
  final Iterable<String>? scopes;

  /// A page of the documentation of the server, for developers.
  final Uri? serviceDocumentation;

  /// Other metadata, which is added last, and so may replace any.
  final Map<String, dynamic> extra;

  /// Throws an [ArgumentError] if [issuer] is not as RFC 8414 §2 has it.
  ServerMetadata({
    required this.issuer,
    this.authorizationEndpoint,
    this.tokenEndpoint,
    this.deviceAuthorizationEndpoint,
    this.revocationEndpoint,
    this.introspectionEndpoint,
    this.responseTypes = const ['code'],
    this.grantTypes = const ['authorization_code'],
    this.clientAuthMethods = const [
      'client_secret_basic',
      'client_secret_post',
    ],
    this.scopes,
    this.serviceDocumentation,
    this.extra = const {},
  }) {
    var local = const {'localhost', '127.0.0.1', '::1'}.contains(issuer.host);
    if (!(issuer.isScheme('https') || (issuer.isScheme('http') && local)) ||
        issuer.host.isEmpty) {
      throw ArgumentError.value(
        issuer,
        'issuer',
        'Must be an https URL, or an http one of localhost',
      );
    }
    if (issuer.hasQuery || issuer.hasFragment) {
      throw ArgumentError.value(
        issuer,
        'issuer',
        'Must have no query nor fragment',
      );
    }
  }

  /// The path at which to route [AuthorizationServer.metadataEndpoint]:
  /// `/.well-known/oauth-authorization-server`, followed by the path of
  /// [issuer], if any (RFC 8414 §3.1).
  String get wellKnownPath {
    var path = issuer.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '/.well-known/oauth-authorization-server$path';
  }
}
