import 'dart:async';
import 'dart:convert';

import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:crypto/crypto.dart';
import 'package:jose_plus/jose.dart';

import 'client.dart';

import 'signing_key.dart';

/// The path of the OpenID Provider configuration (OpenID Connect Discovery
/// 1.0 §4), of the issuer's path.
const openIdConfigurationPath = '/.well-known/openid-configuration';

/// The claims of each standard scope (OpenID Connect Core 1.0 §5.4), which
/// [OpenIdServer.userInfoEndpoint] gives of a token of the scope.
const standardScopeClaims = <String, List<String>>{
  'profile': [
    'name',
    'family_name',
    'given_name',
    'middle_name',
    'nickname',
    'preferred_username',
    'profile',
    'picture',
    'website',
    'gender',
    'birthdate',
    'zoneinfo',
    'locale',
    'updated_at',
  ],
  'email': ['email', 'email_verified'],
  'address': ['address'],
  'phone': ['phone_number', 'phone_number_verified'],
};

/// The OpenID Connect parameters of an authorization request (OpenID
/// Connect Core 1.0 §3.1.2.1), which [OpenIdServer.authorizationEndpoint]
/// gives `requestAuthorizationCode` in `req.container`:
///
/// ```dart
/// var openId = req.container!.make<OpenIdRequest>();
/// if (openId.isOpenId) storeWithTheCode(nonce: openId.nonce);
/// ```
///
/// Making it throws `invalid_request` of a malformed `max_age` or `prompt`,
/// which the endpoint redirects, as its other errors.
class OpenIdRequest {
  /// Whether the request asks for the `openid` scope, of which an ID token
  /// is issued.
  final bool isOpenId;

  /// The `nonce` of the request, which the ID token of its code must give
  /// back, against replay; `null` if it gave none.
  final String? nonce;

  /// The `prompt` values of the request: `none`, `login`, `consent` and
  /// `select_account`. Of `none`, the user must not be prompted: answer
  /// `login_required` or `consent_required` if they would be.
  final Set<String> prompt;

  /// The `max_age` of the request, in seconds: the user must have
  /// authenticated within it, or authenticate again; and the ID token must
  /// then have an `auth_time`.
  final int? maxAge;

  /// The `state` of the request, of which its errors are redirected.
  final String state;

  OpenIdRequest({
    required this.isOpenId,
    this.nonce,
    this.prompt = const {},
    this.maxAge,
    this.state = '',
  });

  /// What the provider must do with the user before it issues a code of
  /// this request (OpenID Connect Core 1.0 §3.1.2.3), of whether they are
  /// [signedIn], since [authTime], and have [consented] to the client; of
  /// the request's `max_age`, or of [defaultMaxAge], the client's: none, to
  /// issue it at once.
  ///
  /// Of `prompt=none`, of which the user may not be prompted, it throws the
  /// error of what they would have had to do instead: `login_required`,
  /// `account_selection_required` or `consent_required`, which the
  /// authorization endpoint redirects. Ask once, before the user is
  /// prompted: of `prompt=login`, it is always [OpenIdInteraction.login].
  Set<OpenIdInteraction> interactions({
    required bool signedIn,
    DateTime? authTime,
    bool consented = true,
    int? defaultMaxAge,
    DateTime? now,
  }) {
    var maxAge = this.maxAge ?? defaultMaxAge;
    var time = now ?? DateTime.now();
    // Of max_age=0, as of prompt=login (OpenID Connect Core 1.0 §3.1.2.1),
    // a login whenever the user authenticated.
    var stale =
        maxAge != null &&
        (maxAge == 0 ||
            authTime == null ||
            time.difference(authTime) > Duration(seconds: maxAge));
    var needed = {
      if (!signedIn || stale || prompt.contains('login'))
        OpenIdInteraction.login,
      if (prompt.contains('select_account')) OpenIdInteraction.selectAccount,
      if (!consented || prompt.contains('consent')) OpenIdInteraction.consent,
    };
    if (prompt.contains('none') && needed.isNotEmpty) {
      var (error, description) = switch (needed.first) {
        OpenIdInteraction.login => (
          OpenIdErrors.loginRequired,
          'The user must sign in.',
        ),
        OpenIdInteraction.selectAccount => (
          OpenIdErrors.accountSelectionRequired,
          'The user must select an account.',
        ),
        OpenIdInteraction.consent => (
          OpenIdErrors.consentRequired,
          'The user must consent to the client.',
        ),
      };
      throw AuthorizationException(
        ErrorResponse(error, description, state),
        statusCode: 400,
      );
    }
    return needed;
  }

  static const _prompts = {'none', 'login', 'consent', 'select_account'};

  /// The OpenID Connect parameters of [params], of an authorization request
  /// of [state].
  factory OpenIdRequest.of(Map<String, dynamic> params, String state) {
    AuthorizationException invalid(String description) =>
        AuthorizationException(
          ErrorResponse(ErrorResponse.invalidRequest, description, state),
          statusCode: 400,
        );

    var scope = params['scope']?.toString() ?? '';
    var isOpenId = scope.split(RegExp(r'\s+')).contains('openid');
    var nonce = params['nonce']?.toString();

    var prompt = {
      for (var value in (params['prompt']?.toString() ?? '').split(' '))
        if (value.isNotEmpty) value,
    };
    for (var value in prompt) {
      if (!_prompts.contains(value)) {
        throw invalid('Unknown "prompt" value "$value".');
      }
    }
    if (prompt.contains('none') && prompt.length > 1) {
      throw invalid('"prompt=none" may not be given with other values.');
    }

    int? maxAge;
    if (params['max_age'] case var value?) {
      maxAge = int.tryParse(value.toString());
      if (maxAge == null || maxAge < 0) {
        throw invalid('The "max_age" parameter must be a number of seconds.');
      }
    }
    return OpenIdRequest(
      isOpenId: isOpenId,
      nonce: nonce == null || nonce.isEmpty ? null : nonce,
      prompt: prompt,
      maxAge: maxAge,
      state: state,
    );
  }
}

/// A token response of an ID token (OpenID Connect Core 1.0 §3.1.3.3), of
/// [OpenIdServer.issueIdToken].
class IdTokenResponse extends AuthorizationTokenResponse {
  /// The signed ID token.
  final String idToken;

  const IdTokenResponse(
    super.accessToken, {
    required this.idToken,
    super.refreshToken,
    super.expiresIn,
    super.scope,
  });

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'id_token': idToken};
}

/// An OAuth2 authorization server that is an OpenID Provider (OpenID
/// Connect Core 1.0): it issues ID tokens, of [issueIdToken], and serves its
/// JSON Web Key Set, of [jwksEndpoint], its configuration, of
/// [openIdConfigurationEndpoint], and the claims of its users, of
/// [userInfoEndpoint].
///
/// Store the [OpenIdRequest] of an authorization request with its code, in
/// `requestAuthorizationCode`, and issue the ID token of it in
/// `exchangeAuthorizationCodeForToken`:
///
/// ```dart
/// var idToken = issueIdToken(
///   user: stored.user,
///   client: client,
///   nonce: stored.nonce,
///   authTime: stored.authTime,
///   accessToken: accessToken,
/// );
/// return IdTokenResponse(accessToken, idToken: idToken);
/// ```
abstract class OpenIdServer<Client, User>
    extends AuthorizationServer<Client, User> {
  /// The issuer of the ID tokens, which is that of the configuration: an
  /// `https` URL of no query or fragment (OpenID Connect Discovery §3).
  final Uri issuer;

  /// The keys of the provider: the first signs the ID tokens, and the JSON
  /// Web Key Set publishes all, so that tokens of a key that is being
  /// replaced still verify. Rotate by putting the new key first, and
  /// removing the old one once its tokens have expired.
  final List<OpenIdSigningKey> signingKeys;

  /// How long an ID token is valid. Default: 10 minutes.
  final Duration idTokenLifetime;

  OpenIdServer({
    required this.issuer,
    required this.signingKeys,
    this.idTokenLifetime = const Duration(minutes: 10),
  }) {
    if (signingKeys.isEmpty) {
      throw ArgumentError.value(
        signingKeys,
        'signingKeys',
        'must not be empty',
      );
    }
    var keyIds = {for (var key in signingKeys) key.keyId};
    if (keyIds.length != signingKeys.length) {
      throw ArgumentError.value(
        signingKeys,
        'signingKeys',
        'must be of distinct key ids',
      );
    }
    if (issuer.hasQuery || issuer.hasFragment) {
      throw ArgumentError.value(
        issuer,
        'issuer',
        'must have no query nor fragment',
      );
    }
    if (!issuer.isScheme('https') &&
        !(issuer.isScheme('http') && loopbackHosts.contains(issuer.host))) {
      throw ArgumentError.value(
        issuer,
        'issuer',
        'must be https, or http of localhost',
      );
    }
    if (!signingKeys.any((key) => key.algorithm == 'RS256')) {
      // OpenID Connect Core 1.0 §15.1: every provider must support RS256.
      throw ArgumentError.value(
        signingKeys,
        'signingKeys',
        'must have an RS256 key, which every OpenID Provider must support',
      );
    }
  }

  /// The subject of [user] (`sub`): an identifier of them at the issuer,
  /// which never changes nor is reused, of at most 255 ASCII characters.
  String subjectOf(User user);

  /// The `client_id` of [client], which is the audience of its ID tokens.
  String clientIdOf(Client client);

  /// The claims of [user], such as their `name` and `email`, which
  /// [userInfoEndpoint] gives of those of the scopes of a token, of
  /// [scopeClaims]. By default, none.
  FutureOr<Map<String, dynamic>> claimsOf(User user) => const {};

  /// The claims of each scope, which [userInfoEndpoint] gives: by default,
  /// [standardScopeClaims]. Add a scope of claims of your own here.
  Map<String, List<String>> get scopeClaims => standardScopeClaims;

  /// The algorithm of the ID tokens of [client], as it registered it. By
  /// default, `null`, of `RS256`, the default of OpenID Connect.
  ///
  /// The server does not know which registration a `Client` is of: of
  /// clients that register themselves, give back what they registered, as
  /// `OpenIdClientMetadata.of(registration.metadata).idTokenSignedResponseAlg`,
  /// or the algorithm they registered is not used.
  String? idTokenAlgorithmOf(Client client) => null;

  /// The `post_logout_redirect_uris` of [client], to which
  /// [endSessionEndpoint] may redirect. By default, none.
  ///
  /// The server does not know which registration a `Client` is of: of
  /// clients that register themselves, give back what they registered, as
  /// `OpenIdClientMetadata.of(registration.metadata).postLogoutRedirectUris`,
  /// or no redirect after a logout is ever allowed.
  FutureOr<Iterable<Uri>> postLogoutRedirectUrisOf(Client client) => const [];

  /// Ends the session of the user of [request], of [endSessionEndpoint]:
  /// sign them out, and revoke their tokens, as you see fit. Of a request of
  /// no [EndSessionRequest.hasIdTokenHint], ask the user first, as anyone
  /// could send them a link to it.
  ///
  /// Answer the request yourself, as of a page asking them, and redirect to
  /// [EndSessionRequest.redirectUri] once they signed out; or answer none,
  /// of which the endpoint redirects there, or answers that they signed out.
  ///
  /// By default, it refuses, `access_denied`, a 403.
  FutureOr<void> endSession(
    EndSessionRequest<Client> request,
    RequestContext req,
    ResponseContext res,
  ) => throw AuthorizationException(
    ErrorResponse(
      ErrorResponse.accessDenied,
      'Signing out is not supported.',
      request.state,
    ),
    statusCode: 403,
  );

  /// The signed ID token (OpenID Connect Core 1.0 §2) of [user], for
  /// [client], of the key that is first of [signingKeys].
  ///
  /// Give it the [nonce] of the authorization request of the code, if it
  /// had one; [authTime], when the user authenticated, which is required if
  /// it had a `max_age`; and the [accessToken] issued with it, of which its
  /// `at_hash` is. [claims] are added, as `acr` or `amr`, but not in place
  /// of those of the token.
  ///
  /// Of a refresh token grant (§12.2), give no [nonce], and the [authTime]
  /// of the first. Of [algorithm], or of [idTokenAlgorithmOf] of the client,
  /// or of `RS256`, it is signed with the first key of it. Give
  /// [requireAuthTime] of a request of `max_age`, or of a client of
  /// `require_auth_time`, of which an [authTime] is required.
  String issueIdToken({
    required User user,
    required Client client,
    String? nonce,
    DateTime? authTime,
    String? accessToken,
    Map<String, dynamic> claims = const {},
    DateTime? now,
    String? algorithm,
    bool requireAuthTime = false,
  }) {
    if (requireAuthTime && authTime == null) {
      throw ArgumentError.value(
        authTime,
        'authTime',
        'is required, of a request of max_age, or a client of '
            'require_auth_time',
      );
    }
    var issued = now ?? DateTime.now();
    int seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;
    // Of the algorithm given, or the client's, of the first key of it.
    // Of RS256, of a client of none of its own, which the default of OpenID
    // Connect is, and which registration recorded for it.
    var alg = algorithm ?? idTokenAlgorithmOf(client) ?? 'RS256';
    var key = signingKeys.firstWhere(
      (key) => key.algorithm == alg,
      orElse: () => throw StateError(
        'No signing key is of the algorithm $alg, of the ID tokens of '
        '${clientIdOf(client)}.',
      ),
    );
    return key.signJwt({
      // Of none of the token's own, as of a stale `nonce`, or an
      // `auth_time` of [requireAuthTime], of what [claims] give.
      for (var MapEntry(:key, :value) in claims.entries)
        if (!_idTokenClaims.contains(key)) key: value,
      'iss': issuer.toString(),
      'sub': subjectOf(user),
      'aud': clientIdOf(client),
      'exp': seconds(issued.add(idTokenLifetime)),
      'iat': seconds(issued),
      'auth_time': ?(authTime == null ? null : seconds(authTime)),
      'nonce': ?nonce,
      'at_hash': ?(accessToken == null ? null : _halfHash(accessToken)),
    });
  }

  /// The claims of an ID token that [issueIdToken] gives itself, which its
  /// `claims` may not.
  static const _idTokenClaims = {
    'iss',
    'sub',
    'aud',
    'exp',
    'iat',
    'auth_time',
    'nonce',
    'at_hash',
  };

  /// The left half of the SHA-256 of [value], in base64url, as `at_hash`
  /// is, of an RS256 or ES256 token (OpenID Connect Core 1.0 §3.1.3.6).
  static String _halfHash(String value) {
    var digest = sha256.convert(ascii.encode(value)).bytes;
    return base64Url.encode(digest.sublist(0, 16)).replaceAll('=', '');
  }

  /// Checks the OpenID Connect parameters of each authorization request,
  /// of [OpenIdRequest.of], of which a malformed `prompt` or `max_age` is
  /// `invalid_request`, redirected, and gives `requestAuthorizationCode`
  /// the [OpenIdRequest] in `req.container`, as it does the `Pkce`.
  ///
  /// Of `prompt=none`, which only the app can answer, as only it knows
  /// whether the user is signed in, `requestAuthorizationCode` must call
  /// [OpenIdRequest.interactions]: else the user is prompted after all.
  /// Call `super` of an override of your own.
  @override
  FutureOr<void> checkAuthorizationRequest(
    Client client,
    Map<String, dynamic> params,
    String state,
    RequestContext req,
  ) {
    var container = req.container!;
    if (!container.has<OpenIdRequest>()) {
      container.registerSingleton<OpenIdRequest>(
        OpenIdRequest.of(params, state),
      );
    }
  }

  /// The JSON Web Key Set of the provider (RFC 7517 §5): the public keys of
  /// [signingKeys], of which clients verify its ID tokens. Route a GET of
  /// the `jwks_uri` of [openIdConfigurationOf] to it.
  RequestHandler get jwksEndpoint {
    var json = {
      'keys': [for (var key in signingKeys) key.publicJwk],
    };
    return (req, res) {
      // Of an hour, so that a key put first is fetched soon after.
      res.headers['cache-control'] = 'public, max-age=3600';
      return json;
    };
  }

  /// The UserInfo endpoint (OpenID Connect Core 1.0 §5.3): of an access
  /// token of the `openid` scope, of `Authorization: Bearer` or, of a POST,
  /// of its form, the `sub` of its user and their claims of [claimsOf], of
  /// the scopes of the token, of [scopeClaims]. Route a GET and a POST to it.
  ///
  /// A token of no user, as of the client credentials grant, is
  /// `invalid_token`; one without the `openid` scope `insufficient_scope`.
  RequestHandler get userInfoEndpoint {
    var guard = requireToken(scopes: ['openid'], allowFormParameter: true);
    return (req, res) async {
      res.headers
        ..['cache-control'] = 'no-store'
        ..['pragma'] = 'no-cache';
      var allowed = await guard(req, res);
      if (allowed != true) return allowed;
      var token = req.container!.make<AccessToken<Client, User>>();
      var user = token.user;
      if (user == null) {
        res.headers['www-authenticate'] =
            'Bearer realm="oauth2", error="invalid_token", '
            'error_description="The access token is of no user."';
        throw AuthorizationException(
          ErrorResponse(
            ErrorResponse.invalidToken,
            'The access token is of no user.',
            null,
          ),
          statusCode: 401,
        );
      }
      var granted = {for (var scope in token.scopes) ...?scopeClaims[scope]};
      var claims = await claimsOf(user);
      return {
        for (var MapEntry(:key, :value) in claims.entries)
          if (granted.contains(key)) key: value,
        'sub': subjectOf(user),
      };
    };
  }

  /// The OpenID Provider configuration (OpenID Connect Discovery 1.0 §3) of
  /// [metadata], as JSON: the metadata of [metadataOf], of its [jwksUri] and
  /// [userInfoEndpoint] URL, the `RS256` and `ES256` of [signingKeys], the
  /// subject type `public`, and the `openid` scope and claims of
  /// [scopeClaims].
  ///
  /// Throws an [ArgumentError] if the issuer of [metadata] is not [issuer],
  /// which clients check against that of each ID token.
  Map<String, dynamic> openIdConfigurationOf(
    ServerMetadata metadata, {
    required Uri jwksUri,
    Uri? userInfoEndpoint,
    Uri? endSessionEndpoint,
  }) {
    if (metadata.issuer != issuer) {
      throw ArgumentError.value(
        metadata.issuer,
        'metadata',
        'must be of the issuer of the server, $issuer',
      );
    }
    var json = metadataOf(metadata);
    var scopes = <String>{
      'openid',
      ...?(json['scopes_supported'] as List?)?.cast<String>(),
      if (metadata.scopes == null) ...scopeClaims.keys,
    };
    return {
      ...json,
      'jwks_uri': jwksUri.toString(),
      'userinfo_endpoint': ?userInfoEndpoint?.toString(),
      'end_session_endpoint': ?endSessionEndpoint?.toString(),
      'scopes_supported': scopes.toList(),
      'subject_types_supported': ['public'],
      'id_token_signing_alg_values_supported': {
        for (var key in signingKeys) key.algorithm,
      }.toList(),
      'claims_supported': {
        'sub',
        'iss',
        'aud',
        'exp',
        'iat',
        'auth_time',
        'nonce',
        for (var claims in scopeClaims.values) ...claims,
      }.toList(),
      'prompt_values_supported': ['none', 'login', 'consent', 'select_account'],
      // Of none of them: of `request_uri_parameter_supported`, whose
      // default is `true`, so it must be said.
      'claims_parameter_supported': false,
      'request_parameter_supported': false,
      'request_uri_parameter_supported': false,
      ...metadata.extra,
    };
  }

  /// A request handler of [openIdConfigurationOf], of a GET of
  /// [openIdConfigurationPath] of the issuer:
  ///
  /// ```dart
  /// app.get(openIdConfigurationPath, server.openIdConfigurationEndpoint(
  ///   metadata,
  ///   jwksUri: Uri.parse('https://example.com/oauth2/jwks'),
  ///   userInfoEndpoint: Uri.parse('https://example.com/oauth2/userinfo'),
  /// ));
  /// ```
  RequestHandler openIdConfigurationEndpoint(
    ServerMetadata metadata, {
    required Uri jwksUri,
    Uri? userInfoEndpoint,
    Uri? endSessionEndpoint,
  }) {
    var json = openIdConfigurationOf(
      metadata,
      jwksUri: jwksUri,
      userInfoEndpoint: userInfoEndpoint,
      endSessionEndpoint: endSessionEndpoint,
    );
    return (req, res) => json;
  }

  /// The OpenID Connect metadata of [metadata] (OpenID Connect Dynamic
  /// Client Registration 1.0 §2), checked, of its defaults, before the
  /// server checks the rest:
  ///
  /// - `post_logout_redirect_uris`, of the form of `redirect_uris`;
  /// - `id_token_signed_response_alg`, of [signingKeys]: `RS256`;
  /// - `subject_type`, `public`, of which pairwise is not supported;
  /// - `default_max_age`, of seconds, and `require_auth_time`: `false`;
  /// - `application_type`, `web` or `native`: `web`;
  /// - `initiate_login_uri`, of `https`.
  ///
  /// Metadata of what the server does not do, as signed or encrypted
  /// UserInfo responses, encrypted ID tokens, and request objects, is
  /// `invalid_client_metadata`. Call `super` of an override of your own.
  @override
  FutureOr<Map<String, dynamic>> checkClientMetadata(
    Map<String, dynamic> metadata,
    RequestContext req,
  ) {
    AuthorizationException invalid(
      String description, {
      String error = ErrorResponse.invalidClientMetadata,
    }) => AuthorizationException(
      ErrorResponse(error, description, null),
      statusCode: 400,
    );

    for (var name in _unsupportedClientMetadata) {
      if (metadata[name] != null) {
        throw invalid('"$name" is not supported.');
      }
    }

    var postLogout = metadata['post_logout_redirect_uris'];
    if (postLogout != null) {
      if (postLogout is! List || postLogout.any((v) => v is! String)) {
        throw invalid('"post_logout_redirect_uris" must be of strings.');
      }
      // Of the rules of `redirect_uris`, of angel3_auth_server.
      for (var value in postLogout.cast<String>()) {
        if (redirectUriProblem(value) case var problem?) {
          throw invalid(
            'The post logout redirect URI "$value" $problem.',
            error: ErrorResponse.invalidRedirectUri,
          );
        }
      }
    }

    var algorithms = {for (var key in signingKeys) key.algorithm};
    var alg = metadata['id_token_signed_response_alg'] ?? 'RS256';
    if (alg is! String || !algorithms.contains(alg)) {
      throw invalid(
        '"id_token_signed_response_alg" must be of ${algorithms.join(', ')}.',
      );
    }
    var subjectType = metadata['subject_type'] ?? 'public';
    if (subjectType != 'public') {
      throw invalid('"subject_type" must be "public".');
    }
    var defaultMaxAge = metadata['default_max_age'];
    if (defaultMaxAge != null && (defaultMaxAge is! int || defaultMaxAge < 0)) {
      throw invalid('"default_max_age" must be a number of seconds.');
    }
    var requireAuthTime = metadata['require_auth_time'] ?? false;
    if (requireAuthTime is! bool) {
      throw invalid('"require_auth_time" must be a boolean.');
    }
    var applicationType = metadata['application_type'] ?? 'web';
    if (applicationType != 'web' && applicationType != 'native') {
      throw invalid('"application_type" must be "web" or "native".');
    }
    var initiateLogin = metadata['initiate_login_uri'];
    var initiateUri = initiateLogin is String
        ? Uri.tryParse(initiateLogin)
        : null;
    if (initiateLogin != null &&
        (initiateUri == null ||
            !initiateUri.isScheme('https') ||
            initiateUri.host.isEmpty)) {
      throw invalid('"initiate_login_uri" must be an https URL.');
    }
    return {
      ...metadata,
      'id_token_signed_response_alg': alg,
      'subject_type': subjectType,
      'require_auth_time': requireAuthTime,
      'application_type': applicationType,
    };
  }

  /// Of the `openid` scope too, which [openIdConfigurationOf] gives, of a
  /// [metadata] of scopes, so that a client may register it.
  @override
  RequestHandler registrationEndpoint(ServerMetadata metadata) =>
      super.registrationEndpoint(_withOpenIdScope(metadata));

  /// Of the `openid` scope too, as [registrationEndpoint].
  @override
  RequestHandler registrationManagementEndpoint(ServerMetadata metadata) =>
      super.registrationManagementEndpoint(_withOpenIdScope(metadata));

  static ServerMetadata _withOpenIdScope(ServerMetadata metadata) {
    var scopes = metadata.scopes;
    if (scopes == null || scopes.contains('openid')) return metadata;
    return metadata.copyWith(scopes: ['openid', ...scopes]);
  }

  /// The metadata of what the server does not do, which a client may not
  /// register.
  static const _unsupportedClientMetadata = {
    'sector_identifier_uri',
    'id_token_encrypted_response_alg',
    'id_token_encrypted_response_enc',
    'userinfo_signed_response_alg',
    'userinfo_encrypted_response_alg',
    'userinfo_encrypted_response_enc',
    'request_object_signing_alg',
    'request_object_encryption_alg',
    'request_object_encryption_enc',
    'request_uris',
  };

  /// The public keys of [signingKeys], of which [_claimsOfOwnToken] checks.
  late final JsonWebKeyStore _ownKeys = () {
    var store = JsonWebKeyStore();
    for (var key in signingKeys) {
      store.addKey(JsonWebKey.fromJson(key.publicJwk));
    }
    return store;
  }();

  /// The claims of [token], if it is an ID token of the provider: of one of
  /// [signingKeys], of [issuer], of the type `JWT` or none, of a `sub` and
  /// an `aud`, and not a logout token, of `events`, so that no other JWT of
  /// the provider's keys passes for one. It may have expired, as an
  /// `id_token_hint` may (OpenID Connect RP-Initiated Logout 1.0 §2).
  Future<Map<String, dynamic>?> _claimsOfOwnToken(String token) async {
    try {
      var jws = JsonWebSignature.fromCompactSerialization(token);
      var type = jws.commonProtectedHeader['typ'];
      if (type != null && type != 'JWT') return null;
      var payload = await jws.getPayload(
        _ownKeys,
        allowedAlgorithms: [for (var key in signingKeys) key.algorithm],
      );
      var claims = payload.jsonContent;
      if (claims is! Map<String, dynamic>) return null;
      if (claims['iss'] != issuer.toString()) return null;
      var sub = claims['sub'];
      if (sub is! String || sub.isEmpty) return null;
      if (claims['aud'] == null || claims.containsKey('events')) return null;
      return claims;
    } catch (_) {
      return null;
    }
  }

  /// Not a logout of no parameters, of a body that cannot be read, which
  /// could sign a user out of a request that was not what it seemed.
  static AuthorizationException _unreadableBody() => AuthorizationException(
    ErrorResponse(
      ErrorResponse.invalidRequest,
      'The body of the request cannot be read.',
      null,
    ),
    statusCode: 400,
  );

  /// The end session endpoint (OpenID Connect RP-Initiated Logout 1.0): of
  /// a GET or POST of a client that signs its user out, of its
  /// `id_token_hint`, which must be an ID token of the provider, expired or
  /// not; its `client_id`, which must be the audience of the hint; its
  /// `post_logout_redirect_uri`, which must be one of
  /// [postLogoutRedirectUrisOf] the client; and its `state`. Route a GET and
  /// a POST to it.
  ///
  /// Once they are checked, [endSession] is given the [EndSessionRequest],
  /// to sign the user out; then, unless it answered, the user is redirected
  /// to the `post_logout_redirect_uri`, of the `state`, or told that they
  /// signed out. A request that is not valid is `invalid_request`, a 400,
  /// and never redirected.
  RequestHandler get endSessionEndpoint {
    return (req, res) async {
      res.headers
        ..['cache-control'] = 'no-store'
        ..['pragma'] = 'no-cache';
      Map<String, dynamic> params;
      if (req.method.toUpperCase() == 'POST') {
        try {
          await req.parseBody();
          params = req.bodyAsMap;
        } on FormatException {
          throw _unreadableBody();
        } on AuthorizationException {
          rethrow;
        } on AngelHttpException catch (e) {
          // Of the framework's 400 of a body it cannot read; of another, as
          // a 413, its own.
          if (e.statusCode != 400) rethrow;
          throw _unreadableBody();
        }
      } else {
        params = req.queryParameters;
      }
      String? param(String name) {
        var value = params[name]?.toString();
        return value == null || value.isEmpty ? null : value;
      }

      var state = param('state');
      AuthorizationException invalid(String description) =>
          AuthorizationException(
            ErrorResponse(ErrorResponse.invalidRequest, description, state),
            statusCode: 400,
          );

      String? subject;
      List<String>? audience;
      var hint = param('id_token_hint');
      if (hint != null) {
        var claims = await _claimsOfOwnToken(hint);
        if (claims == null) {
          throw invalid(
            'The "id_token_hint" is not an ID token of this provider.',
          );
        }
        subject = claims['sub'] as String;
        var aud = claims['aud'];
        audience = aud is String
            ? [aud]
            : aud is List && aud.every((v) => v is String)
            ? aud.cast<String>()
            : null;
        if (audience == null || audience.isEmpty) {
          throw invalid('The "id_token_hint" has no audience.');
        }
      }

      var clientId = param('client_id');
      if (clientId != null &&
          audience != null &&
          !audience.contains(clientId)) {
        throw invalid(
          'The "client_id" is not of the audience of the "id_token_hint".',
        );
      }
      // Of a hint of one audience, its client; of several, the client_id
      // must say which.
      if (clientId == null && audience != null) {
        if (audience.length > 1) {
          throw invalid(
            'The "id_token_hint" is of several audiences: give the '
            '"client_id".',
          );
        }
        clientId = audience.single;
      }
      Client? client;
      if (clientId != null) {
        client = await findClient(clientId);
        if (client == null) throw invalid('Unknown client "$clientId".');
      }

      Uri? redirect;
      var postLogout = param('post_logout_redirect_uri');
      if (postLogout != null) {
        // Of a registered URI of the client alone, as an open redirect else
        // (RP-Initiated Logout §3).
        if (client == null) {
          throw invalid(
            'A "post_logout_redirect_uri" requires the "id_token_hint" or '
            '"client_id" of its client.',
          );
        }
        var registered = await postLogoutRedirectUrisOf(client);
        if (!registered.any((uri) => uri.toString() == postLogout)) {
          throw invalid(
            'The "post_logout_redirect_uri" is not registered for the client.',
          );
        }
        redirect = Uri.parse(postLogout);
      }

      var request = EndSessionRequest<Client>(
        subject: subject,
        client: client,
        hasIdTokenHint: hint != null,
        postLogoutRedirectUri: redirect,
        state: state,
      );
      await endSession(request, req, res);
      if (!res.isOpen) return false;
      if (request.redirectUri case var uri?) {
        await res.redirect(uri);
        return false;
      }
      return {'signed_out': true};
    };
  }
}
