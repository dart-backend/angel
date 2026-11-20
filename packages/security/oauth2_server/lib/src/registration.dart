import 'server.dart';

/// A client that registers itself at the
/// [AuthorizationServer.registrationEndpoint] (RFC 7591), of the metadata it
/// gives, once the server has checked it, and of the id and secret that the
/// server issues it, which [AuthorizationServer.registerClient] stores.
class ClientRegistration {
  /// The id that the server issues the client.
  final String clientId;

  /// The secret that the server issues the client, or `null` of a public
  /// client, of the [tokenEndpointAuthMethod] `none`. Store it as a
  /// password, hashed, and compare with it in
  /// [AuthorizationServer.verifyClient].
  ///
  /// Of a registration that [AuthorizationServer.findRegistration] reads
  /// back, `null`, as the server keeps only its hash; and of one that
  /// [AuthorizationServer.updateClient] is given, `null` unless it is new,
  /// so that the secret is kept.
  final String? clientSecret;

  /// The token with which the client manages its registration at its
  /// [registrationClientUri] (RFC 7592), if the server manages them, of
  /// [AuthorizationServer.managesClientRegistrations]: store it hashed, as
  /// the secret. As [clientSecret], `null` once it is stored, and of an
  /// update, unless it is new.
  final String? registrationAccessToken;

  /// The URL at which the client manages its registration, of
  /// [AuthorizationServer.registrationManagementEndpoint], if the server
  /// manages them.
  final Uri? registrationClientUri;

  /// When the id was issued.
  final DateTime issuedAt;

  /// The `redirect_uris` of the client, of its redirect grants.
  final List<Uri> redirectUris;

  /// The `grant_types` of the client.
  final List<String> grantTypes;

  /// The `response_types` of the client.
  final List<String> responseTypes;

  /// The `token_endpoint_auth_method` of the client: `client_secret_basic`,
  /// `client_secret_post` or `none`.
  final String tokenEndpointAuthMethod;

  /// The scopes of the `scope` of the client, if it gave one.
  final List<String>? scopes;

  /// The metadata of the client, as JSON: what it gave, which the server
  /// has checked, of the defaults of what it did not give. Change it in
  /// [AuthorizationServer.registerClient] to register other values, which
  /// the response then gives (RFC 7591 §3.2.1).
  final Map<String, dynamic> metadata;

  ClientRegistration({
    required this.clientId,
    required this.clientSecret,
    required this.issuedAt,
    required this.redirectUris,
    required this.grantTypes,
    required this.responseTypes,
    required this.tokenEndpointAuthMethod,
    required this.scopes,
    required this.metadata,
    this.registrationAccessToken,
    this.registrationClientUri,
  });

  /// This registration, of the values given in place of its own. A `null`
  /// keeps its value, so a field, such as [clientSecret], cannot be cleared
  /// by it: build a [ClientRegistration] for that.
  ClientRegistration copyWith({
    String? clientId,
    String? clientSecret,
    DateTime? issuedAt,
    List<Uri>? redirectUris,
    List<String>? grantTypes,
    List<String>? responseTypes,
    String? tokenEndpointAuthMethod,
    List<String>? scopes,
    Map<String, dynamic>? metadata,
    String? registrationAccessToken,
    Uri? registrationClientUri,
  }) => ClientRegistration(
    clientId: clientId ?? this.clientId,
    clientSecret: clientSecret ?? this.clientSecret,
    issuedAt: issuedAt ?? this.issuedAt,
    redirectUris: redirectUris ?? this.redirectUris,
    grantTypes: grantTypes ?? this.grantTypes,
    responseTypes: responseTypes ?? this.responseTypes,
    tokenEndpointAuthMethod:
        tokenEndpointAuthMethod ?? this.tokenEndpointAuthMethod,
    scopes: scopes ?? this.scopes,
    metadata: metadata ?? this.metadata,
    registrationAccessToken:
        registrationAccessToken ?? this.registrationAccessToken,
    registrationClientUri: registrationClientUri ?? this.registrationClientUri,
  );

  /// The response of the registration (RFC 7591 §3.2.1, RFC 7592 §3): the
  /// id and secret of the client, when they were issued and when the secret
  /// expires, which it does not, the token and URL with which it manages
  /// the registration, if any, and its [metadata].
  Map<String, dynamic> toJson() => {
    ...metadata,
    'client_id': clientId,
    'client_id_issued_at': issuedAt.millisecondsSinceEpoch ~/ 1000,
    if (clientSecret != null) ...{
      'client_secret': clientSecret,
      'client_secret_expires_at': 0,
    },
    'registration_access_token': ?registrationAccessToken,
    if (registrationClientUri != null)
      'registration_client_uri': registrationClientUri.toString(),
  };
}
