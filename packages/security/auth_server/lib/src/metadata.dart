import 'server.dart';

/// The hosts of the machine itself, of which an `http` URL is accepted, as
/// of an issuer, or a redirect URI of a native app (RFC 8252 §7.3). Of
/// [Uri.host], which drops the brackets of `[::1]`.
const loopbackHosts = {'localhost', '127.0.0.1', '::1'};

/// Why [value] may not be a redirect URI of a client, as of its
/// `redirect_uris` or `post_logout_redirect_uris`, or `null` if it may: it
/// must be absolute, of no fragment, and `https`, `http` of [loopbackHosts],
/// or of the private-use scheme of a native app, a reverse domain name, such
/// as `com.example.app:` (RFC 8252 §7.1); any other scheme, as
/// `javascript:`, is refused.
///
/// The reason completes a sentence of the URI: "The redirect URI ... must
/// have a host."
String? redirectUriProblem(String value) {
  var uri = Uri.tryParse(value);
  if (uri == null || !uri.isAbsolute || uri.hasFragment) {
    return 'must be absolute, of no fragment';
  }
  if (uri.isScheme('http') && !loopbackHosts.contains(uri.host)) {
    return 'must be https, or http of localhost';
  }
  if ((uri.isScheme('https') || uri.isScheme('http')) && uri.host.isEmpty) {
    return 'must have a host';
  }
  if (!uri.isScheme('https') &&
      !uri.isScheme('http') &&
      !uri.scheme.contains('.')) {
    return 'must be https, http of localhost, or of a reverse domain name '
        'scheme, such as "com.example.app:"';
  }
  return null;
}

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

  /// The URL of [AuthorizationServer.registrationEndpoint].
  final Uri? registrationEndpoint;

  /// The `response_type`s that the authorization endpoint supports: `code`,
  /// and `token`, if the server implements implicit grants, which
  /// [AuthorizationServer.allowsImplicitGrant] must then allow.
  final Iterable<String> responseTypes;

  /// The grant types that the server implements, such as `refresh_token`,
  /// `password` or `client_credentials`; the server adds those of its
  /// [AuthorizationServer.extensionGrants], the device code grant, if
  /// [deviceAuthorizationEndpoint] is given, and `implicit`, if
  /// [responseTypes] has `token`.
  final Iterable<String> grantTypes;

  /// The client authentication methods of the token endpoint, and of the
  /// revocation endpoint: `client_secret_basic`, of the `Authorization:
  /// Basic` header, and `client_secret_post`, of the form; add `none` if
  /// the server has public clients. Those of the introspection endpoint
  /// are these, but `none`, as its callers must have a secret.
  final Iterable<String> clientAuthMethods;

  /// The scopes that the server supports, if it publishes them; a client
  /// may register no other.
  final Iterable<String>? scopes;

  /// A page of the documentation of the server, for developers.
  final Uri? serviceDocumentation;

  /// Whether the server issues access tokens bound to the client
  /// certificate of their request (RFC 8705 §3.3), as
  /// `AccessToken.certificateThumbprint`; a client may then register
  /// `tls_client_certificate_bound_access_tokens`.
  final bool tlsClientCertificateBoundAccessTokens;

  /// The URLs of the endpoints at which the server asks for client
  /// certificates, by the names of their metadata, such as
  /// `token_endpoint`, if they are not those above, as of another host
  /// (RFC 8705 §5).
  final Map<String, Uri>? mtlsEndpointAliases;

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
    this.registrationEndpoint,
    this.responseTypes = const ['code'],
    this.grantTypes = const ['authorization_code'],
    this.clientAuthMethods = const [
      'client_secret_basic',
      'client_secret_post',
    ],
    this.scopes,
    this.serviceDocumentation,
    this.tlsClientCertificateBoundAccessTokens = false,
    this.mtlsEndpointAliases,
    this.extra = const {},
  }) {
    var local = loopbackHosts.contains(issuer.host);
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

  /// This metadata, of the values given in place of its own. A `null` keeps
  /// the value of this metadata: to remove one, as its [scopes], build a
  /// [ServerMetadata] instead.
  ServerMetadata copyWith({
    Uri? issuer,
    Uri? authorizationEndpoint,
    Uri? tokenEndpoint,
    Uri? deviceAuthorizationEndpoint,
    Uri? revocationEndpoint,
    Uri? introspectionEndpoint,
    Uri? registrationEndpoint,
    Iterable<String>? responseTypes,
    Iterable<String>? grantTypes,
    Iterable<String>? clientAuthMethods,
    Iterable<String>? scopes,
    Uri? serviceDocumentation,
    bool? tlsClientCertificateBoundAccessTokens,
    Map<String, Uri>? mtlsEndpointAliases,
    Map<String, dynamic>? extra,
  }) => ServerMetadata(
    issuer: issuer ?? this.issuer,
    authorizationEndpoint: authorizationEndpoint ?? this.authorizationEndpoint,
    tokenEndpoint: tokenEndpoint ?? this.tokenEndpoint,
    deviceAuthorizationEndpoint:
        deviceAuthorizationEndpoint ?? this.deviceAuthorizationEndpoint,
    revocationEndpoint: revocationEndpoint ?? this.revocationEndpoint,
    introspectionEndpoint: introspectionEndpoint ?? this.introspectionEndpoint,
    registrationEndpoint: registrationEndpoint ?? this.registrationEndpoint,
    responseTypes: responseTypes ?? this.responseTypes,
    grantTypes: grantTypes ?? this.grantTypes,
    clientAuthMethods: clientAuthMethods ?? this.clientAuthMethods,
    scopes: scopes ?? this.scopes,
    serviceDocumentation: serviceDocumentation ?? this.serviceDocumentation,
    tlsClientCertificateBoundAccessTokens:
        tlsClientCertificateBoundAccessTokens ??
        this.tlsClientCertificateBoundAccessTokens,
    mtlsEndpointAliases: mtlsEndpointAliases ?? this.mtlsEndpointAliases,
    extra: extra ?? this.extra,
  );

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
