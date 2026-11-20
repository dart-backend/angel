import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:logging/logging.dart';

import 'access_token.dart';
import 'exception.dart';
import 'metadata.dart';
import 'pkce.dart';
import 'registration.dart';
import 'response.dart';
import 'token_type.dart';

/// A request handler that performs an arbitrary authorization token grant.
typedef ExtensionGrant = FutureOr<AuthorizationTokenResponse> Function(
  RequestContext req,
  ResponseContext res,
);

/// The parameters of [req]: of its form if [body], or else of its query.
Future<Map<String, dynamic>> _paramsOf(
  RequestContext req, {
  bool body = false,
}) async => body
    ? await req.parseBody().then((_) => req.bodyAsMap)
    : req.queryParameters;

Future<String?> _getParam(
  RequestContext req,
  String name,
  String state, {
  bool body = false,
  bool throwIfEmpty = true,
}) async {
  var data = await _paramsOf(req, body: body);
  var value = data.containsKey(name) ? data[name]?.toString() : null;

  if (value?.isNotEmpty != true && throwIfEmpty) {
    throw AuthorizationException(
      ErrorResponse(
        ErrorResponse.invalidRequest,
        'Missing required parameter "$name".',
        state,
      ),
      statusCode: 400,
    );
  }

  return value;
}

Future<Iterable<String>> _getScopes(
  RequestContext req, {
  bool body = false,
}) async {
  var data = await _paramsOf(req, body: body);
  // Separated by spaces (RFC 6749 §3.3), of which there may be several.
  return [
    for (var scope in data['scope']?.toString().split(_whitespace) ?? [])
      if (scope.isNotEmpty) scope,
  ];
}

/// Throws the error of a grant that the server does not support, as the
/// default of each grant method does: `unsupported_grant_type`, with the
/// `state` of the form of [req].
Future<Never> _unsupportedGrant(RequestContext req, String description) async {
  var body = await _paramsOf(req, body: true);
  throw AuthorizationException(
    ErrorResponse(
      ErrorResponse.unsupportedGrantType,
      description,
      body['state']?.toString() ?? '',
    ),
    statusCode: 400,
  );
}

final _whitespace = RegExp(r'\s+');

/// An OAuth2 authorization server, which issues access tokens to third parties.
abstract class AuthorizationServer<Client, User> {
  static Logger logger = Logger('AuthorizationServer');

  const AuthorizationServer();

  static const String _internalServerError =
      'An internal server error occurred.';

  /// A [Map] of custom authorization token grants. Use this to handle custom grant types, perhaps even your own.
  Map<String, ExtensionGrant> get extensionGrants => {};

  /// Finds the [Client] application associated with the given [clientId].
  FutureOr<Client>? findClient(String? clientId);

  /// Verify that a [client] is the one identified by the [clientSecret]:
  /// `null` if the request gives none.
  ///
  /// Return `true` of a `null` secret only for a public client, which has
  /// none, and of a secret only for a confidential client, whose secret it
  /// is: never of any secret for a public client, as anyone may give its
  /// id, and a client that gives a secret is taken to be confidential, as
  /// of the client credentials grant and of introspection.
  FutureOr<bool> verifyClient(Client client, String? clientSecret);

  /// Retrieves the PKCE `code_verifier` parameter from a [RequestContext], or throws.
  Future<String> getPkceCodeVerifier(
    RequestContext req, {
    bool body = true,
    String? state,
    Uri? uri,
  }) async {
    var data = await _paramsOf(req, body: body);
    var codeVerifier = data['code_verifier'];

    if (codeVerifier == null || codeVerifier == '') {
      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.invalidRequest,
          'Missing `code_verifier` parameter.',
          state,
          uri: uri,
        ),
      );
    } else if (codeVerifier is! String) {
      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.invalidRequest,
          'The `code_verifier` parameter must be a string.',
          state,
          uri: uri,
        ),
      );
    } else {
      return codeVerifier;
    }
  }

  /// The redirect URI registered for [client] that an authorization request
  /// gives as [redirectUri], or, if it gives none, the one registered for
  /// the client (RFC 6749 §3.1.2.3). Throw an [AuthorizationException] if
  /// [redirectUri] is not one of the client's: it is not redirected.
  ///
  /// Once it returns one, the request may leave out its `redirect_uri`, and
  /// its errors, those of [requestAuthorizationCode] among them, are
  /// redirected to the URI, with the `state` of the request (RFC 6749
  /// §4.1.2.1, §4.2.2.1).
  ///
  /// By default, `null`: the server does not know the redirect URIs of its
  /// clients, so that the request must give a `redirect_uri`, which
  /// [requestAuthorizationCode] is to check, and its errors are not
  /// redirected, as the URI may be an attacker's.
  FutureOr<Uri?> registeredRedirectUri(Client client, String? redirectUri) =>
      null;

  /// Whether an authorization code grant of [client] must use PKCE (RFC
  /// 7636): its authorization request must give a `code_challenge`, and its
  /// token request a `code_verifier`, each of 43 to 128 characters, or it is
  /// `invalid_request`.
  ///
  /// By default, `true` for every client, as OAuth 2.1 and RFC 9700 have
  /// it. Return `false` for clients that cannot use PKCE yet. Either way,
  /// [exchangeAuthorizationCodeForToken] must still compare the verifier
  /// with the challenge stored with the code, by [Pkce.validate].
  FutureOr<bool> requiresPkce(Client client) => true;

  /// Whether a `code_challenge_method` of `plain`, which is the challenge
  /// itself, or none, which is `plain`, is accepted.
  ///
  /// By default, `false`: only `S256` is, as OAuth 2.1 and RFC 9700 have
  /// it, as anyone who sees the authorization request can redeem its code
  /// otherwise.
  bool get allowsPlainPkce => false;

  /// A `code_challenge` or a `code_verifier` (RFC 7636 §4.1, §4.2): an
  /// `S256` challenge is the base64url of 32 bytes, of 43 characters.
  static final RegExp _rgxPkce = RegExp(r'^[A-Za-z0-9\-._~]{43,128}$');

  /// Throws `invalid_request` unless the authorization code request of
  /// [client] gives a `code_challenge` of [params] as [requiresPkce] and
  /// [allowsPlainPkce] have it.
  Future<void> _checkPkceChallenge(
    Client client,
    Map<String, dynamic> params,
    String state,
  ) async {
    AuthorizationException invalid(String description) =>
        AuthorizationException(
          ErrorResponse(ErrorResponse.invalidRequest, description, state),
          statusCode: 400,
        );

    var required = await requiresPkce(client);
    var challenge = params['code_challenge']?.toString() ?? '';
    if (challenge.isEmpty) {
      if (required) {
        throw invalid('Missing "code_challenge" parameter; PKCE is required.');
      }
      return;
    }
    var method = params['code_challenge_method']?.toString() ?? 'plain';
    var s256 = method == 'S256' || method == 's256';
    if (!s256 && (method != 'plain' || !allowsPlainPkce)) {
      throw invalid(
        allowsPlainPkce
            ? 'The "code_challenge_method" parameter must be "S256" or '
                  '"plain".'
            : 'The "code_challenge_method" parameter must be "S256".',
      );
    }
    // Of the padding that earlier clients gave an S256 challenge; a plain
    // one is the verifier, which has none.
    var unpadded = s256 ? unpaddedChallenge(challenge) : challenge;
    if (required && !_rgxPkce.hasMatch(unpadded)) {
      throw invalid(
        'The "code_challenge" parameter must be of 43 to 128 characters of '
        'A-Z, a-z, 0-9, "-", ".", "_" and "~".',
      );
    }
  }

  /// The [AccessToken] that the server issued as [token], of a request to a
  /// resource that [requireToken] protects, or `null` if it issued none, or
  /// has revoked it. [requireToken] refuses one that has expired.
  ///
  /// By default, `null`: implement it to look up the tokens that the grant
  /// methods issue.
  FutureOr<AccessToken<Client, User>?> findAccessToken(
    String token,
    RequestContext req,
  ) => null;

  /// A request handler that protects the resources of the handlers after it
  /// (RFC 6750): it refuses a request without an access token of the server
  /// that grants [scopes], and gives the handlers after it its
  /// [AccessToken], of [findAccessToken], in `req.container`:
  ///
  /// ```dart
  /// app.get('/me', chain([
  ///   server.requireToken(scopes: ['profile']),
  ///   (req, res) {
  ///     var token = req.container!.make<AccessToken<Client, User>>();
  ///     return token.user;
  ///   },
  /// ]));
  /// ```
  ///
  /// The token is of the `Authorization: Bearer` header, or, if
  /// [allowFormParameter], of the `access_token` of the form of a request
  /// that is not a GET (RFC 6750 §2.2); never of the query, which is logged.
  ///
  /// A request without a token is a 401 with `WWW-Authenticate: Bearer
  /// realm="[realm]"`; one of an unknown, revoked or expired token is
  /// `invalid_token`, a 401, and one of a token that does not grant
  /// [scopes] is `insufficient_scope`, a 403, with the scopes it requires;
  /// one of a malformed token, or of several, is `invalid_request`, a 400
  /// (RFC 6750 §3).
  RequestHandler requireToken({
    Iterable<String> scopes = const [],
    String realm = 'oauth2',
    bool allowFormParameter = false,
  }) {
    var required = List<String>.of(scopes);
    return (req, res) async {
      AuthorizationException refuse(
        String error,
        String description,
        int statusCode,
      ) => _bearerError(
        res,
        realm,
        error,
        description,
        statusCode,
        scope: error == ErrorResponse.insufficientScope ? required : null,
      );

      var tokens = _bearerHeaderTokens(req, res, realm);
      if (allowFormParameter && req.method.toUpperCase() != 'GET') {
        var contentType = req.headers!.contentType?.mimeType;
        if (contentType == 'application/x-www-form-urlencoded') {
          var body = await _paramsOf(req, body: true);
          var token = _formValue(body, 'access_token');
          if (token != null) tokens.add(token);
        }
      }
      if (req.uri?.queryParameters.containsKey('access_token') == true) {
        logger.warning(
          'An access token was given in the query of a request, where it '
          'may be logged; it is not read (RFC 6750 §2.3).',
        );
      }

      var tokenString = _requiredBearerToken(
        tokens,
        res,
        realm,
        'An access token is required.',
      );

      var token = await findAccessToken(tokenString, req);
      if (token == null || token.isExpiredAt(DateTime.now())) {
        throw refuse(
          ErrorResponse.invalidToken,
          token == null
              ? 'The access token is not valid.'
              : 'The access token has expired.',
          401,
        );
      }
      var granted = token.scopes.toSet();
      if (!required.every(granted.contains)) {
        throw refuse(
          ErrorResponse.insufficientScope,
          'The access token does not grant the scopes this requires.',
          403,
        );
      }

      // Once, as of several [requireToken] of a request, of its group and
      // of its route, of the same token.
      var container = req.container!;
      if (!container.has<AccessToken<Client, User>>()) {
        container.registerSingleton<AccessToken<Client, User>>(token);
      }
      return true;
    };
  }

  /// The error [error] of a request to a resource that a Bearer token
  /// protects, of the `WWW-Authenticate` of RFC 6750 §3, with the [scope]
  /// that it requires, if any.
  static AuthorizationException _bearerError(
    ResponseContext res,
    String realm,
    String error,
    String description,
    int statusCode, {
    Iterable<String>? scope,
  }) {
    res.headers['www-authenticate'] = [
      'Bearer realm="$realm"',
      'error="$error"',
      'error_description="$description"',
      if (scope != null) 'scope="${scope.join(' ')}"',
    ].join(', ');
    return AuthorizationException(
      ErrorResponse(error, description, null),
      statusCode: statusCode,
    );
  }

  /// The one token of [tokens], or `null` if there is none; throws
  /// `invalid_request` if there are several.
  static String? _optionalBearerToken(
    List<String> tokens,
    ResponseContext res,
    String realm,
  ) {
    if (tokens.length > 1) {
      throw _bearerError(
        res,
        realm,
        ErrorResponse.invalidRequest,
        'More than one access token.',
        400,
      );
    }
    return tokens.firstOrNull;
  }

  /// The one token of [tokens]; throws `invalid_request` if there are
  /// several, and the 401 challenge of [missing] if there is none.
  static String _requiredBearerToken(
    List<String> tokens,
    ResponseContext res,
    String realm,
    String missing,
  ) =>
      _optionalBearerToken(tokens, res, realm) ??
      (throw _bearerChallenge(res, realm, missing));

  /// The 401 challenge of a request that gives no token, without an error,
  /// as it did not try to authenticate (RFC 6750 §3.1).
  static AngelHttpException _bearerChallenge(
    ResponseContext res,
    String realm,
    String message,
  ) {
    res.headers['www-authenticate'] = 'Bearer realm="$realm"';
    return AngelHttpException.notAuthenticated(message: message);
  }

  /// The tokens of the `Authorization: Bearer` headers of [req]; throws
  /// `invalid_request` if one is malformed.
  static List<String> _bearerHeaderTokens(
    RequestContext req,
    ResponseContext res,
    String realm,
  ) {
    var tokens = <String>[];
    for (var value in req.headers!['authorization'] ?? const <String>[]) {
      // Of headers joined by commas, as of the shelf driver: a token has
      // none.
      for (var part in value.split(',')) {
        if (!_rgxBearerScheme.hasMatch(part)) continue;
        var match = _rgxBearer.firstMatch(part);
        if (match == null) {
          throw _bearerError(
            res,
            realm,
            ErrorResponse.invalidRequest,
            'Malformed "Authorization" header.',
            400,
          );
        }
        tokens.add(match[1]!);
      }
    }
    return tokens;
  }

  /// Of any case (RFC 7235 §2.1).
  static final RegExp _rgxBearerScheme = RegExp(
    r'^\s*Bearer(\s|$)',
    caseSensitive: false,
  );

  /// The `b64token` of a Bearer header (RFC 6750 §2.1).
  static final RegExp _rgxBearer = RegExp(
    r'^\s*Bearer\s+([A-Za-z0-9\-._~+/]+=*)\s*$',
    caseSensitive: false,
  );

  /// Prompt the currently logged-in user to grant or deny access to the [client].
  ///
  /// In many applications, this will entail showing a dialog to the user in question.
  ///
  /// If [implicit] is `true`, then the client is requesting an *implicit grant*.
  /// Be aware of the security implications of this - do not handle them exactly
  /// the same.
  ///
  /// [redirectUri] is that of [registeredRedirectUri], if it gives one, or
  /// else the `redirect_uri` of the request, which must then be checked
  /// against those of the [client].
  FutureOr<void> requestAuthorizationCode(
    Client client,
    String? redirectUri,
    Iterable<String> scopes,
    String state,
    RequestContext req,
    ResponseContext res,
    bool implicit,
  ) {
    throw AuthorizationException(
      ErrorResponse(
        ErrorResponse.unsupportedResponseType,
        'Authorization code grants are not supported.',
        state,
      ),
      statusCode: 400,
    );
  }

  /// Exchanges an authorization code for an authorization token.
  ///
  /// [redirectUri] is `null` if the request gives none, which it must if
  /// the authorization request of the code gave one, and must be the same
  /// (RFC 6749 §4.1.3): check it against the one stored with the code.
  FutureOr<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
    Client? client,
    String? authCode,
    String? redirectUri,
    RequestContext req,
    ResponseContext res,
  ) => _unsupportedGrant(req, 'Authorization code grants are not supported.');

  /// Refresh an authorization token.
  FutureOr<AuthorizationTokenResponse> refreshAuthorizationToken(
    Client? client,
    String? refreshToken,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) => _unsupportedGrant(
    req,
    'Refreshing authorization tokens is not supported.',
  );

  /// Issue an authorization token to a user after authenticating them via [username] and [password].
  FutureOr<AuthorizationTokenResponse> resourceOwnerPasswordCredentialsGrant(
    Client? client,
    String? username,
    String? password,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) => _unsupportedGrant(
    req,
    'Resource owner password credentials grants are not supported.',
  );

  /// Performs a client credentials grant, of the [scopes] the client asks
  /// for. Only use this in situations where the client is 100% trusted.
  FutureOr<AuthorizationTokenResponse> clientCredentialsGrant(
    Client? client,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) => _unsupportedGrant(req, 'Client credentials grants are not supported.');

  /// Performs a device authorization request (RFC 8628 §3.1), of the
  /// [deviceAuthorizationEndpoint].
  ///
  /// By default, device codes are not supported: `unsupported_grant_type`.
  FutureOr<DeviceCodeResponse> requestDeviceCode(
    Client client,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) => _unsupportedGrant(req, 'Device code grants are not supported.');

  /// Produces an authorization token from a given device code.
  FutureOr<AuthorizationTokenResponse> exchangeDeviceCodeForToken(
    Client client,
    String? deviceCode,
    String state,
    RequestContext req,
    ResponseContext res,
  ) => _unsupportedGrant(req, 'Device code grants are not supported.');

  /// Returns the [Uri] that a client can be redirected to in the case of an implicit grant.
  Uri completeImplicitGrant(
    AuthorizationTokenResponse token,
    Uri redirectUri, {
    String? state,
  }) {
    var queryParameters = <String, String>{};

    queryParameters.addAll({
      'access_token': token.accessToken,
      'token_type': 'bearer',
    });

    // Only of a request that gave one (RFC 6749 §4.2.2).
    if (state != null && state.isNotEmpty) queryParameters['state'] = state;

    if (token.expiresIn != null) {
      queryParameters['expires_in'] = token.expiresIn.toString();
    }

    if (token.scope != null) queryParameters['scope'] = token.scope!.join(' ');

    // Form-encoded, as its errors are (RFC 6749 Appendix B).
    return redirectUri.replace(
      fragment: Uri(queryParameters: queryParameters).query,
    );
  }

  /// A request handler that invokes the correct logic, depending on which type
  /// of grant the client is requesting.
  ///
  /// Its errors are redirected to the redirect URI of the client, once
  /// [registeredRedirectUri] has given one; before, or without one, as of
  /// an unknown client, they are thrown.
  Future<void> authorizationEndpoint(
    RequestContext req,
    ResponseContext res,
  ) async {
    var state = '';

    try {
      // Of the query, or of the form of a POST (RFC 6749 §3.1).
      var post = req.method.toUpperCase() == 'POST';
      var params = await _paramsOf(req, body: post);
      state = params['state']?.toString() ?? '';

      req.container!.registerLazySingleton<Pkce>((_) {
        return Pkce.fromJson(params, state: state);
      });

      // Ensure client ID
      var clientId = await _getParam(req, 'client_id', state, body: post);

      // Find client
      var client = await findClient(clientId);

      if (client == null) {
        throw AuthorizationException(
          ErrorResponse(
            ErrorResponse.invalidRequest,
            'Unknown client "$clientId".',
            state,
          ),
        );
      }

      var given = await _getParam(
        req,
        'redirect_uri',
        state,
        body: post,
        throwIfEmpty: false,
      );
      var registered = await registeredRedirectUri(
        client,
        given == null || given.isEmpty ? null : given,
      );
      var responseType = params['response_type']?.toString();

      Future<void> authorize() async {
        var redirectUri =
            registered?.toString() ??
            await _getParam(req, 'redirect_uri', state, body: post);

        if (responseType == null || responseType.isEmpty) {
          throw AuthorizationException(
            ErrorResponse(
              ErrorResponse.invalidRequest,
              'Missing required parameter "response_type".',
              state,
            ),
            statusCode: 400,
          );
        }
        if (responseType != 'code' && responseType != 'token') {
          throw AuthorizationException(
            ErrorResponse(
              ErrorResponse.unsupportedResponseType,
              'Unsupported "response_type" parameter: "$responseType".',
              state,
            ),
            statusCode: 400,
          );
        }

        if (responseType == 'code') {
          await _checkPkceChallenge(client, params, state);
        }

        // Grab scopes
        var scopes = await _getScopes(req, body: post);

        return await requestAuthorizationCode(
          client,
          redirectUri,
          scopes,
          state,
          req,
          res,
          responseType == 'token',
        );
      }

      if (registered == null) return await authorize();

      Future<void> redirectError(ErrorResponse error) => res.redirect(
        _errorRedirect(
          registered,
          error,
          state,
          fragment: responseType == 'token',
        ),
      );

      try {
        return await authorize();
      } on AuthorizationException catch (e) {
        if (!res.isOpen) rethrow;
        return await redirectError(e.errorResponse);
      } on AngelHttpException {
        rethrow;
      } catch (e, st) {
        // `server_error`, which a client cannot learn of otherwise, as the
        // user is not on its page (RFC 6749 §4.1.2.1).
        if (!res.isOpen) rethrow;
        logger.severe('The authorization request failed', e, st);
        return await redirectError(
          ErrorResponse(ErrorResponse.serverError, _internalServerError, state),
        );
      }
    } on AngelHttpException {
      rethrow;
    } catch (e, st) {
      throw AuthorizationException(
        ErrorResponse(ErrorResponse.serverError, _internalServerError, state),
        error: e,
        statusCode: 500,
        stackTrace: st,
      );
    }
  }

  /// [redirectUri] with the authorization [code] of an authorization code
  /// grant, and the [state] of its request, if any, in its query, to which
  /// the user is redirected once they grant access (RFC 6749 §4.1.2); the
  /// query of [redirectUri] is kept.
  Uri completeAuthorizationCode(
    String code,
    Uri redirectUri, {
    String? state,
  }) => _withParameters(redirectUri, {
    'code': code,
    if (state != null && state.isNotEmpty) 'state': state,
  });

  /// [uri] with [parameters] after its query, which is kept as it is
  /// (RFC 6749 §3.1.2).
  static Uri _withParameters(Uri uri, Map<String, String> parameters) {
    var added = Uri(queryParameters: parameters).query;
    return uri.replace(
      query: uri.query.isEmpty ? added : '${uri.query}&$added',
    );
  }

  /// [redirectUri] with the parameters of [error], and [state] if any: in
  /// its query, or in its [fragment], as of an implicit grant (RFC 6749
  /// §4.1.2.1, §4.2.2.1).
  static Uri _errorRedirect(
    Uri redirectUri,
    ErrorResponse error,
    String state, {
    required bool fragment,
  }) {
    var parameters = {
      'error': error.code,
      if (error.description.isNotEmpty) 'error_description': error.description,
      if (error.uri != null) 'error_uri': error.uri.toString(),
      if (state.isNotEmpty) 'state': state,
    };
    return fragment
        ? redirectUri.replace(fragment: Uri(queryParameters: parameters).query)
        : _withParameters(redirectUri, parameters);
  }

  /// The grant types that [tokenEndpoint] handles, besides
  /// [extensionGrants].
  static const _grantTypes = {
    'authorization_code',
    'refresh_token',
    'password',
    'client_credentials',
    _deviceCodeGrantType,
  };

  static const _deviceCodeGrantType =
      'urn:ietf:params:oauth:grant-type:device_code';

  /// Of any case, as an authentication scheme (RFC 7235 §2.1).
  static final RegExp _rgxBasic = RegExp(
    r'^\s*Basic\s+(\S+)\s*$',
    caseSensitive: false,
  );

  /// A header of the `Basic` scheme, malformed or not.
  static final RegExp _rgxBasicScheme = RegExp(
    r'^\s*Basic(\s|$)',
    caseSensitive: false,
  );

  /// The `Authorization` header of [req] of the `Basic` scheme, of all its
  /// values, as a proxy may add one of another scheme, which is not of the
  /// client; or `null` if there is none. Throws `invalid_request` if there
  /// are several.
  ///
  /// Each value is split at its commas too, as `HttpClient` and the shelf
  /// driver join headers of one name with them: Basic credentials, of
  /// base64, have none, and the parts of the parameters of another scheme
  /// are not of the `Basic` scheme.
  static String? _basicHeader(RequestContext req, String state) {
    var basic = [
      for (var value in req.headers!['authorization'] ?? const <String>[])
        for (var part in value.split(','))
          if (_rgxBasicScheme.hasMatch(part)) part,
    ];
    if (basic.length > 1) {
      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.invalidRequest,
          'More than one Basic "Authorization" header.',
          state,
        ),
        statusCode: 400,
      );
    }
    return basic.firstOrNull;
  }

  /// The parameter [name] of the form [body], or `null` if it is empty, as
  /// an empty one is of none.
  static String? _formValue(Map<String, dynamic> body, String name) {
    var value = body[name]?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  /// The client id and secret of an `Authorization: Basic` [header], split
  /// at the first `:`, as an id has none, but a secret may; or `null` if it
  /// is malformed, or its id is empty.
  ///
  /// Each is percent-decoded, as clients encode them (RFC 6749 §2.3.1),
  /// unless that fails, as of a `%` sent unencoded; a `+` is kept, as
  /// `package:oauth2` does not encode it.
  static (String, String)? _basicCredentials(String header) {
    var match = _rgxBasic.firstMatch(header);
    if (match == null) return null;
    String credentials;
    try {
      // Either base64 alphabet, padded or not; the credentials are UTF-8
      // (RFC 7617).
      credentials = utf8.decode(base64.decode(base64.normalize(match[1]!)));
    } on FormatException {
      return null;
    }
    var colon = credentials.indexOf(':');
    if (colon <= 0) return null;
    return (
      _percentDecoded(credentials.substring(0, colon)),
      _percentDecoded(credentials.substring(colon + 1)),
    );
  }

  /// [value] percent-decoded, or as it is if it is not valid: of a `%` of
  /// no two hex digits, or of escapes that are not of UTF-8, as `%FF`.
  static String _percentDecoded(String value) {
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    } on FormatException {
      return value;
    }
  }

  /// The error of a client that could not be authenticated:
  /// `invalid_client`, a 401 (RFC 6749 §5.2), with the `WWW-Authenticate` of
  /// Basic authentication if [challenge], as when the client used it, or
  /// gave no credentials.
  static AuthorizationException _invalidClient(
    ResponseContext res,
    String description,
    String state, {
    required bool challenge,
  }) {
    if (challenge) res.headers['www-authenticate'] = 'Basic realm="oauth2"';
    return AuthorizationException(
      ErrorResponse(ErrorResponse.invalidClient, description, state),
      statusCode: 401,
    );
  }

  /// The client of a request to the token endpoint, of any grant, device
  /// code requests among them, authenticated by its `Authorization: Basic`
  /// header, or, without one, as with one of another scheme, by the
  /// `client_id` and `client_secret` of its form (RFC 6749 §2.3.1), of
  /// which a public client, as of PKCE or a device, gives no secret:
  /// [verifyClient] is given `null`, as for an empty one, and decides
  /// whether the client may have none. A `client_id` of the form, given
  /// with the header, must be of its client.
  ///
  /// Also whether the client gave a secret, as a confidential client does.
  Future<(Client, bool)> _authenticateClient(
    RequestContext req,
    ResponseContext res,
    Map<String, dynamic> body,
    String state,
  ) async {
    var header = _basicHeader(req, state);
    // Whether the client used Basic authentication, as of a challenge.
    var challenge = header != null;
    String clientId;
    String? clientSecret;
    if (header != null) {
      var credentials = _basicCredentials(header);
      if (credentials == null) {
        throw _invalidClient(
          res,
          'Invalid "Authorization" header.',
          state,
          challenge: true,
        );
      }
      (clientId, clientSecret) = credentials;
      // As of `Basic id:`, as of none.
      if (clientSecret.isEmpty) clientSecret = null;
    } else {
      var id = _formValue(body, 'client_id');
      if (id == null) {
        throw _invalidClient(
          res,
          'No client credentials: no Basic "Authorization" header, nor '
          '"client_id" parameter.',
          state,
          // Of no credentials, which Basic would give.
          challenge: true,
        );
      }
      clientId = id;
      clientSecret = _formValue(body, 'client_secret');
    }

    var client = await findClient(clientId);
    if (client == null) {
      throw _invalidClient(
        res,
        'Unknown client "$clientId".',
        state,
        challenge: challenge,
      );
    }
    if (!await verifyClient(client, clientSecret)) {
      throw _invalidClient(
        res,
        'Invalid client credentials.',
        state,
        challenge: challenge,
      );
    }
    if (header != null) _checkFormOfHeader(body, clientId, clientSecret, state);
    return (client, clientSecret != null);
  }

  /// Throws `invalid_request` if the form of a request that authenticated
  /// by its `Authorization: Basic` header has a `client_id` or a
  /// `client_secret` that is not the header's, once the header is known to
  /// be of a client: RFC 8628 has a client give its `client_id`, and some
  /// give the secret too, but a request has one method of authentication
  /// (RFC 6749 §2.3).
  static void _checkFormOfHeader(
    Map<String, dynamic> body,
    String clientId,
    String? clientSecret,
    String state,
  ) {
    var formId = _formValue(body, 'client_id');
    var formSecret = _formValue(body, 'client_secret');
    String? differs;
    if (formId != null && formId != clientId) {
      differs = 'client_id';
    } else if (formSecret != null && formSecret != clientSecret) {
      differs = 'client_secret';
    }
    if (differs != null) {
      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.invalidRequest,
          'The "$differs" parameter is not that of the "Authorization" '
          'header.',
          state,
        ),
        statusCode: 400,
      );
    }
  }

  /// Revokes [token], which [client] gives to a [revocationEndpoint], an
  /// access token or a refresh token, which [tokenTypeHint] may name:
  /// `access_token` or `refresh_token`, or `null`. Look it up by the hint
  /// first, and by the other type if it is not found (RFC 7009 §2.1).
  ///
  /// Revoke it only if it was issued to [client]. Do nothing for a token
  /// that is unknown, already revoked, or of another client: the response
  /// is a 200 either way, which tells the caller nothing of it (§2.2). Also
  /// revoke the tokens of the same grant, such as the access tokens of a
  /// refresh token, as the server can.
  ///
  /// Throw `unsupported_token_type` for a type of token that the server
  /// cannot revoke, as it does by default, of a server that does not
  /// support revocation.
  FutureOr<void> revokeToken(
    Client client,
    String token,
    String? tokenTypeHint,
    RequestContext req,
    ResponseContext res,
  ) => throw AuthorizationException(
    ErrorResponse(
      ErrorResponse.unsupportedTokenType,
      'Token revocation is not supported.',
      null,
    ),
    statusCode: 400,
  );

  /// A request handler of token revocation requests (RFC 7009), as of a
  /// client that logs its user out. Route a POST to it:
  ///
  /// ```dart
  /// router.post('/revoke', server.revocationEndpoint);
  /// ```
  ///
  /// Its client is authenticated as at the [tokenEndpoint]: a public one by
  /// its `client_id` alone. It gives the `token` of the form, and its
  /// `token_type_hint`, to [revokeToken], and answers a 200, without a
  /// body, whether the token was revoked or not; or errors as the
  /// [tokenEndpoint] does: `invalid_request` without a `token`.
  Future<void> revocationEndpoint(
    RequestContext req,
    ResponseContext res,
  ) async {
    var state = '';
    res.headers
      ..['cache-control'] = 'no-store'
      ..['pragma'] = 'no-cache';

    try {
      var body = await _paramsOf(req, body: true);
      state = body['state']?.toString() ?? '';
      var (client, _) = await _authenticateClient(req, res, body, state);
      var token = _formValue(body, 'token');
      if (token == null) {
        throw AuthorizationException(
          ErrorResponse(
            ErrorResponse.invalidRequest,
            'Missing required parameter "token".',
            state,
          ),
          statusCode: 400,
        );
      }
      await revokeToken(
        client,
        token,
        _formValue(body, 'token_type_hint'),
        req,
        res,
      );
      if (res.isOpen) {
        res.statusCode = 200;
        await res.close();
      }
    } on AngelHttpException {
      rethrow;
    } catch (e, st) {
      throw AuthorizationException(
        ErrorResponse(ErrorResponse.serverError, _internalServerError, state),
        error: e,
        statusCode: 500,
        stackTrace: st,
      );
    }
  }

  /// The token of the server that [token] is, of an introspection request
  /// whose `token_type_hint` is [tokenTypeHint], `access_token`,
  /// `refresh_token` or `null`; or `null` if the server issued none, or has
  /// revoked it. An expired one is inactive.
  ///
  /// By default, the access token of [findAccessToken], whatever the hint;
  /// override it to find refresh tokens too.
  FutureOr<AccessToken<Client, User>?> introspectToken(
    String token,
    String? tokenTypeHint,
    RequestContext req,
  ) => findAccessToken(token, req);

  /// Whether [caller], a client with a secret, may introspect tokens at the
  /// [introspectionEndpoint], as a resource server of the server does; one
  /// that may not is `access_denied`, a 403 (RFC 7662 §4).
  ///
  /// By default, `false`: no client may, as any client with a secret, such
  /// as a web app, would otherwise learn of the tokens of others. Return
  /// `true` of the clients that are resource servers.
  FutureOr<bool> mayIntrospect(Client caller, RequestContext req) => false;

  /// What an introspection response of the active [token] gives [caller],
  /// besides `active`, `scope`, `exp` and `iat`, which the server adds: such
  /// as `client_id`, `username`, `sub`, `aud`, `iss`, `token_type` or `jti`
  /// (RFC 7662 §2.2); or `null` if [caller] may not learn of the token, as
  /// one of a resource server that it is not for, which is then inactive.
  ///
  /// By default, nothing more, to any caller that [mayIntrospect].
  FutureOr<Map<String, dynamic>?> introspectionClaims(
    Client caller,
    AccessToken<Client, User> token,
  ) => const {};

  /// A request handler of token introspection requests (RFC 7662), of a
  /// resource server that asks whether a token of a request it is given is
  /// active, and of what. Route a POST to it:
  ///
  /// ```dart
  /// router.post('/introspect', server.introspectionEndpoint);
  /// ```
  ///
  /// Its caller is authenticated as a client, as at the [tokenEndpoint],
  /// and must give a secret, as anyone may give the id of a public client:
  /// one without is `invalid_client`. It must be one that [mayIntrospect],
  /// or it is `access_denied`, a 403. It gives the `token` of the form, and
  /// its `token_type_hint`, to [introspectToken], and answers `{"active":
  /// false}` for one that is unknown, revoked or expired, or that
  /// [introspectionClaims] does not give to the caller; or else `active`,
  /// the `scope`, `exp` and `iat` of the token, and its
  /// [introspectionClaims]. A request without a `token` is
  /// `invalid_request`.
  Future<Map<String, dynamic>> introspectionEndpoint(
    RequestContext req,
    ResponseContext res,
  ) async {
    var state = '';
    res.headers
      ..['cache-control'] = 'no-store'
      ..['pragma'] = 'no-cache';

    try {
      var body = await _paramsOf(req, body: true);
      state = body['state']?.toString() ?? '';
      var (caller, confidential) = await _authenticateClient(
        req,
        res,
        body,
        state,
      );
      if (!confidential) {
        // Against the scanning of tokens (RFC 7662 §4).
        throw _invalidClient(
          res,
          'A client without a secret may not introspect tokens.',
          state,
          challenge: true,
        );
      }
      if (!await mayIntrospect(caller, req)) {
        throw AuthorizationException(
          ErrorResponse(
            ErrorResponse.accessDenied,
            'This client may not introspect tokens.',
            state,
          ),
          statusCode: 403,
        );
      }
      var tokenString = _formValue(body, 'token');
      if (tokenString == null) {
        throw AuthorizationException(
          ErrorResponse(
            ErrorResponse.invalidRequest,
            'Missing required parameter "token".',
            state,
          ),
          statusCode: 400,
        );
      }

      const inactive = <String, dynamic>{'active': false};
      var token = await introspectToken(
        tokenString,
        _formValue(body, 'token_type_hint'),
        req,
      );
      if (token == null || token.isExpiredAt(DateTime.now())) return inactive;
      var claims = await introspectionClaims(caller, token);
      if (claims == null) return inactive;

      int seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;
      return {
        if (token.scopes.isNotEmpty) 'scope': token.scopes.join(' '),
        if (token.expiresAt case var expiresAt?) 'exp': seconds(expiresAt),
        if (token.issuedAt case var issuedAt?) 'iat': seconds(issuedAt),
        ...claims,
        // Last, as the claims may not make it otherwise.
        'active': true,
      };
    } on AngelHttpException {
      rethrow;
    } catch (e, st) {
      throw AuthorizationException(
        ErrorResponse(ErrorResponse.serverError, _internalServerError, state),
        error: e,
        statusCode: 500,
        stackTrace: st,
      );
    }
  }

  /// Whether a client may register itself at the [registrationEndpoint]:
  /// of the initial access token of its `Authorization: Bearer` header,
  /// [initialAccessToken], which the server gave its developer, or `null`
  /// (RFC 7591 §3).
  ///
  /// By default, `false`: no client may. Return `true` of a token that the
  /// server issued for registration; or for any, of open registration,
  /// which anyone may use, with limits on how often.
  FutureOr<bool> mayRegisterClient(
    String? initialAccessToken,
    RequestContext req,
  ) => false;

  /// Stores the client of [registration], of its id, its secret, hashed,
  /// and its [ClientRegistration.metadata], so that [findClient] finds it,
  /// and [verifyClient] verifies its secret, and
  /// [registeredRedirectUri] its redirect URIs.
  ///
  /// Throw an [AuthorizationException] of `invalid_client_metadata` or
  /// `invalid_redirect_uri` to refuse a value that the server does not
  /// accept; or change [ClientRegistration.metadata] to register another.
  FutureOr<void> registerClient(
    ClientRegistration registration,
    RequestContext req,
  ) => throw AuthorizationException(
    ErrorResponse(
      ErrorResponse.accessDenied,
      'Client registration is not supported.',
      null,
    ),
    statusCode: 403,
  );

  /// A request handler of client registration requests (RFC 7591), of a
  /// client that registers itself, of the JSON of its metadata, and is
  /// given an id, and a secret unless it is public. Route a POST to it:
  ///
  /// ```dart
  /// router.post('/register', server.registrationEndpoint(metadata));
  /// ```
  ///
  /// A client may register only if [mayRegisterClient] gives it. Its
  /// metadata is checked against [metadata]: its `grant_types`,
  /// `response_types`, `token_endpoint_auth_method` and `scope` must be of
  /// those of the server, its grant and response types of each other, and
  /// its `redirect_uris`, which its redirect grants require, absolute, of no
  /// fragment, and of `https`, of `http` only for `localhost`, or of a
  /// scheme of a native app (RFC 8252 §7.1). A public client may not use the
  /// client credentials grant. A `software_statement` is not verified, and
  /// is dropped.
  ///
  /// The client is given to [registerClient], and the response is a 201 of
  /// its [ClientRegistration.toJson]; or an error, a 400 of
  /// `invalid_client_metadata` or `invalid_redirect_uri`, or a 401 of a
  /// missing or refused initial access token.
  ///
  /// Throws an [ArgumentError] if [managesClientRegistrations], and
  /// [metadata] does not give its `registrationEndpoint`.
  RequestHandler registrationEndpoint(ServerMetadata metadata) {
    // Once, so that the requests are of what was checked.
    var manages = managesClientRegistrations;
    if (manages && metadata.registrationEndpoint == null) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'Must give the registrationEndpoint, of which the URL of each '
            'registration is a path, as managesClientRegistrations',
      );
    }
    var server = metadataOf(metadata);
    return (req, res) async {
      res.headers
        ..['cache-control'] = 'no-store'
        ..['pragma'] = 'no-cache';
      try {
        const realm = 'oauth2';
        var token = _optionalBearerToken(
          _bearerHeaderTokens(req, res, realm),
          res,
          realm,
        );
        if (!await mayRegisterClient(token, req)) {
          if (token == null) {
            throw _bearerChallenge(
              res,
              realm,
              'An initial access token is required.',
            );
          }
          throw _bearerError(
            res,
            realm,
            ErrorResponse.invalidToken,
            'The initial access token is not valid.',
            401,
          );
        }

        var body = await _jsonObjectOf(req);
        var registration = _registrationOf(body, server, metadata);
        if (manages) {
          registration = _withRegistrationAccess(
            registration,
            metadata,
            newToken: true,
          );
        }
        await registerClient(registration, req);
        res.statusCode = 201;
        return registration.toJson();
      } on AngelHttpException {
        rethrow;
      } catch (e, st) {
        throw AuthorizationException(
          ErrorResponse(ErrorResponse.serverError, _internalServerError, ''),
          error: e,
          statusCode: 500,
          stackTrace: st,
        );
      }
    };
  }

  /// Whether a client that registers itself may then read, update and
  /// delete its registration, at its `registration_client_uri`, of the
  /// [registrationManagementEndpoint], with the `registration_access_token`
  /// that the [registrationEndpoint] then issues it (RFC 7592).
  ///
  /// By default, `false`. If `true`, the [ServerMetadata] of the endpoints
  /// must give their `registrationEndpoint`, of which the URL of each
  /// registration is a path.
  bool get managesClientRegistrations => false;

  /// Whether an update of a registration issues its client a new
  /// registration access token, which [updateClient] stores; the client
  /// must then use it. By default, `false`.
  bool get rotatesRegistrationAccessToken => false;

  /// Whether an update of a registration issues its confidential client a
  /// new secret, which [updateClient] stores. By default, `false`.
  bool get rotatesClientSecretOnUpdate => false;

  /// The registration of the client of [clientId], as [registerClient] or
  /// [updateClient] stored it, if [registrationAccessToken] is its token, of
  /// a request to the [registrationManagementEndpoint]; or `null` if there
  /// is none, or the token is not its, which is `invalid_token`, of either,
  /// so that it tells nothing of other clients (RFC 7592 §2).
  ///
  /// Compare the token with its hash in constant time. Its
  /// [ClientRegistration.clientSecret] and
  /// [ClientRegistration.registrationAccessToken] are `null`, as only their
  /// hashes are kept.
  ///
  /// By default, `null`.
  FutureOr<ClientRegistration?> findRegistration(
    String clientId,
    String registrationAccessToken,
    RequestContext req,
  ) => null;

  /// Stores [updated], the registration that replaces [current], of a PUT to
  /// the [registrationManagementEndpoint]. Its secret and registration access
  /// token are `null` unless they are new, as of a rotation, or of a client
  /// that is no longer public: store them only then, and keep the current
  /// ones otherwise; but if its [ClientRegistration.tokenEndpointAuthMethod]
  /// is `none`, the client is now public: delete its secret.
  ///
  /// Throw `invalid_client_metadata` or `invalid_redirect_uri` to refuse a
  /// value, or change [ClientRegistration.metadata] to register another.
  ///
  /// By default, it refuses updates, `access_denied`, a 403.
  FutureOr<void> updateClient(
    ClientRegistration current,
    ClientRegistration updated,
    RequestContext req,
  ) => throw AuthorizationException(
    ErrorResponse(
      ErrorResponse.accessDenied,
      'Updating client registrations is not supported.',
      null,
    ),
    statusCode: 403,
  );

  /// Deletes the client of [registration], of a DELETE to the
  /// [registrationManagementEndpoint], and revokes its tokens and grants,
  /// and its registration access token, so that it is unknown from then on.
  ///
  /// By default, it refuses deletion, `access_denied`, a 403.
  FutureOr<void> deleteClient(
    ClientRegistration registration,
    RequestContext req,
  ) => throw AuthorizationException(
    ErrorResponse(
      ErrorResponse.accessDenied,
      'Deleting client registrations is not supported.',
      null,
    ),
    statusCode: 403,
  );

  /// The metadata that a client may not give in an update of its
  /// registration, which the server issues (RFC 7592 §2.2).
  static const _issuedOnUpdate = {
    'registration_access_token',
    'registration_client_uri',
    'client_id_issued_at',
    'client_secret_expires_at',
  };

  /// A request handler of the registrations of clients (RFC 7592), at the
  /// `registration_client_uri` that the [registrationEndpoint] gives each,
  /// of [managesClientRegistrations]: its `registrationEndpoint` of
  /// [metadata], followed by the id of the client, `:client_id`. Route a
  /// GET, a PUT and a DELETE to it:
  ///
  /// ```dart
  /// var manage = server.registrationManagementEndpoint(metadata);
  /// router
  ///   ..get('/register/:client_id', manage)
  ///   ..put('/register/:client_id', manage)
  ///   ..delete('/register/:client_id', manage);
  /// ```
  ///
  /// Each is authenticated by the `registration_access_token` of the client,
  /// of an `Authorization: Bearer` header, by [findRegistration]: one that
  /// is missing is a 401 challenge, and one that is not of the client, or
  /// of a client that does not exist, `invalid_token`, a 401.
  ///
  /// - A GET gives the registration, a 200.
  /// - A PUT replaces it, of the JSON of all its metadata, of which it
  ///   checks what the [registrationEndpoint] checks, and of the `client_id`
  ///   of the client, and its `client_secret`, if given, which [verifyClient]
  ///   verifies, and not what the server issues; it gives the [updateClient]
  ///   the registration, and answers it, a 200.
  /// - A DELETE gives the registration to [deleteClient], and answers a 204.
  ///
  /// Throws an [ArgumentError] unless [managesClientRegistrations], and
  /// [metadata] gives its `registrationEndpoint`.
  RequestHandler registrationManagementEndpoint(ServerMetadata metadata) {
    if (!managesClientRegistrations) {
      throw ArgumentError(
        'The server does not manage client registrations: override '
        'managesClientRegistrations.',
      );
    }
    if (metadata.registrationEndpoint == null) {
      throw ArgumentError.value(
        metadata,
        'metadata',
        'Must give the registrationEndpoint',
      );
    }
    var server = metadataOf(metadata);
    return (req, res) async {
      res.headers
        ..['cache-control'] = 'no-store'
        ..['pragma'] = 'no-cache';
      try {
        const realm = 'oauth2';
        var token = _requiredBearerToken(
          _bearerHeaderTokens(req, res, realm),
          res,
          realm,
          'A registration access token is required.',
        );
        var clientId = req.params['client_id']?.toString() ?? '';
        var found = clientId.isEmpty
            ? null
            : await findRegistration(clientId, token, req);
        if (found == null || found.clientId != clientId) {
          throw _bearerError(
            res,
            realm,
            ErrorResponse.invalidToken,
            'The registration access token is not valid.',
            401,
          );
        }
        var current = _withRegistrationAccess(found, metadata, newToken: false);

        switch (req.method.toUpperCase()) {
          case 'GET':
            // Of its token, which the response must give (RFC 7592 §3).
            return current.copyWith(registrationAccessToken: token).toJson();
          case 'PUT':
            var body = await _jsonObjectOf(req);
            if (body['client_id'] != clientId) {
              throw _invalidMetadata(
                'The "client_id" must be that of the registration.',
              );
            }
            for (var name in _issuedOnUpdate) {
              if (body.containsKey(name)) {
                throw _invalidMetadata(
                  '"$name" is issued by the server, and may not be given.',
                );
              }
            }
            if (body['client_secret'] case var secret?) {
              var client = await findClient(clientId);
              if (secret is! String ||
                  client == null ||
                  !await verifyClient(client, secret)) {
                throw _invalidMetadata(
                  'The "client_secret" must be that of the client.',
                );
              }
            }
            var updated = _withRegistrationAccess(
              _registrationOf(
                body,
                server,
                metadata,
                current: current,
                newSecret: rotatesClientSecretOnUpdate,
              ),
              metadata,
              newToken: rotatesRegistrationAccessToken,
            );
            await updateClient(current, updated, req);
            return updated
                .copyWith(
                  registrationAccessToken:
                      updated.registrationAccessToken ?? token,
                )
                .toJson();
          case 'DELETE':
            await deleteClient(current, req);
            if (res.isOpen) {
              res.statusCode = 204;
              await res.close();
            }
            return null;
          default:
            throw AngelHttpException.methodNotAllowed();
        }
      } on AngelHttpException {
        rethrow;
      } catch (e, st) {
        throw AuthorizationException(
          ErrorResponse(ErrorResponse.serverError, _internalServerError, ''),
          error: e,
          statusCode: 500,
          stackTrace: st,
        );
      }
    };
  }

  /// The JSON object of the body of [req]; throws `invalid_client_metadata`
  /// if it is none.
  static Future<Map<String, dynamic>> _jsonObjectOf(RequestContext req) async {
    Object? body;
    if (req.headers!.contentType?.mimeType == 'application/json') {
      try {
        await req.parseBody();
        body = req.bodyAsObject;
      } on FormatException {
        body = null;
      }
    }
    if (body is! Map) {
      throw _invalidMetadata('The request must be a JSON object.');
    }
    return Map<String, dynamic>.from(body);
  }

  /// [registration] of the URL at which its client manages it, of
  /// [metadata], and of a new registration access token if [newToken].
  static ClientRegistration _withRegistrationAccess(
    ClientRegistration registration,
    ServerMetadata metadata, {
    required bool newToken,
  }) {
    var endpoint = metadata.registrationEndpoint!;
    return registration.copyWith(
      registrationAccessToken: newToken ? _randomString(32) : null,
      registrationClientUri: endpoint.replace(
        pathSegments: [
          for (var segment in endpoint.pathSegments)
            if (segment.isNotEmpty) segment,
          registration.clientId,
        ],
      ),
    );
  }

  static AuthorizationException _invalidMetadata(
    String description, {
    String error = ErrorResponse.invalidClientMetadata,
  }) => AuthorizationException(
    ErrorResponse(error, description, null),
    statusCode: 400,
  );

  /// The metadata that the server issues, or does not verify, which a
  /// client may not register.
  static const _issuedMetadata = {
    'client_id',
    'client_secret',
    'client_id_issued_at',
    'client_secret_expires_at',
    'registration_access_token',
    'registration_client_uri',
    'software_statement',
  };

  /// Of the ids and secrets that the server issues.
  static final Random _random = Random.secure();

  /// [bytes] random bytes, as base64url, without padding.
  static String _randomString(int bytes) => base64Url
      .encode([for (var i = 0; i < bytes; i++) _random.nextInt(256)])
      .replaceAll('=', '');

  /// The registration of the client metadata [body], checked against the
  /// metadata of the server, [server], of [metadataOf], of [metadata].
  ///
  /// Of an update of [current], it keeps its id, when it was issued, and its
  /// secret, which is `null` but if it is new, as of a client that was
  /// public, or if [newSecret].
  ClientRegistration _registrationOf(
    Map<String, dynamic> body,
    Map<String, dynamic> server,
    ServerMetadata metadata, {
    ClientRegistration? current,
    bool newSecret = false,
  }) {
    List<String>? strings(String name) {
      var value = body[name];
      if (value == null) return null;
      if (value is! List || value.any((v) => v is! String)) {
        throw _invalidMetadata('"$name" must be an array of strings.');
      }
      return List<String>.of(value.cast<String>());
    }

    String? string(String name) {
      var value = body[name];
      if (value == null || value is String) return value as String?;
      throw _invalidMetadata('"$name" must be a string.');
    }

    void subset(String name, List<String> values, Iterable supported) {
      for (var value in values) {
        if (!supported.contains(value)) {
          throw _invalidMetadata(
            'The "$name" value "$value" is not supported.',
          );
        }
      }
    }

    // Each, if not given, of the other, as they go together (RFC 7591
    // §2.1): a client of no redirect grant need not give empty response
    // types, nor one of the `token` response type the `implicit` grant.
    var givenResponseTypes = strings('response_types');
    var grantTypes =
        strings('grant_types') ??
        switch (givenResponseTypes) {
          var types? when types.contains('token') => [
            if (types.contains('code')) 'authorization_code',
            'implicit',
          ],
          _ => ['authorization_code'],
        };
    subset('grant_types', grantTypes, server['grant_types_supported'] as List);

    var responseTypes =
        givenResponseTypes ??
        [
          if (grantTypes.contains('authorization_code')) 'code',
          if (grantTypes.contains('implicit')) 'token',
        ];
    subset('response_types', responseTypes, metadata.responseTypes);
    // Of each other (RFC 7591 §2.1).
    for (var (grant, response) in [
      ('authorization_code', 'code'),
      ('implicit', 'token'),
    ]) {
      if (grantTypes.contains(grant) != responseTypes.contains(response)) {
        throw _invalidMetadata(
          'The grant type "$grant" and the response type "$response" must be '
          'registered together.',
        );
      }
    }

    var authMethod =
        string('token_endpoint_auth_method') ?? 'client_secret_basic';
    subset('token_endpoint_auth_method', [
      authMethod,
    ], metadata.clientAuthMethods);
    var public = authMethod == 'none';
    if (public && grantTypes.contains('client_credentials')) {
      throw _invalidMetadata(
        'A client without a secret may not use the client credentials grant.',
      );
    }

    var scope = string('scope');
    List<String>? scopes;
    if (scope != null) {
      scopes = [
        for (var s in scope.split(_whitespace))
          if (s.isNotEmpty) s,
      ];
      if (metadata.scopes case var supported?) {
        subset('scope', scopes, supported);
      }
    }

    var redirectUris = <Uri>[];
    for (var value in strings('redirect_uris') ?? const <String>[]) {
      var uri = Uri.tryParse(value);
      String? problem;
      if (uri == null || !uri.isAbsolute || uri.hasFragment) {
        problem = 'must be absolute, of no fragment';
      } else if (uri.isScheme('http') && !loopbackHosts.contains(uri.host)) {
        problem = 'must be https, or http of localhost';
      } else if ((uri.isScheme('https') || uri.isScheme('http')) &&
          uri.host.isEmpty) {
        problem = 'must have a host';
      } else if (!uri.isScheme('https') &&
          !uri.isScheme('http') &&
          !uri.scheme.contains('.')) {
        // A native app's private-use scheme is a reverse domain name
        // (RFC 8252 §7.1); any other, as `javascript:`, is refused.
        problem =
            'must be https, http of localhost, or of a reverse domain '
            'name scheme, such as "com.example.app:"';
      }
      if (problem != null) {
        throw _invalidMetadata(
          'The redirect URI "$value" $problem.',
          error: ErrorResponse.invalidRedirectUri,
        );
      }
      redirectUris.add(uri!);
    }
    if (redirectUris.isEmpty && responseTypes.isNotEmpty) {
      throw _invalidMetadata(
        'A client of the authorization endpoint must register its '
        '"redirect_uris".',
        error: ErrorResponse.invalidRedirectUri,
      );
    }

    for (var name in [
      'client_name',
      'client_uri',
      'logo_uri',
      'tos_uri',
      'policy_uri',
      'jwks_uri',
      'software_id',
      'software_version',
    ]) {
      var value = string(name);
      if (value != null && name.endsWith('_uri')) {
        var uri = Uri.tryParse(value);
        if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
          throw _invalidMetadata('"$name" must be an http or https URL.');
        }
      }
    }
    strings('contacts');
    if (body['jwks_uri'] != null && body['jwks'] != null) {
      throw _invalidMetadata('"jwks_uri" and "jwks" may not both be given.');
    }

    var wasPublic = current?.tokenEndpointAuthMethod == 'none';
    return ClientRegistration(
      clientId: current?.clientId ?? _randomString(16),
      clientSecret: public || (current != null && !wasPublic && !newSecret)
          ? null
          : _randomString(32),
      issuedAt: current?.issuedAt ?? DateTime.now(),
      redirectUris: redirectUris,
      grantTypes: grantTypes,
      responseTypes: responseTypes,
      tokenEndpointAuthMethod: authMethod,
      scopes: scopes,
      metadata: {
        // Not of what the server issues, nor of a statement it does not
        // verify.
        for (var MapEntry(:key, :value) in body.entries)
          if (!_issuedMetadata.contains(key)) key: value,
        'redirect_uris': [for (var uri in redirectUris) uri.toString()],
        'grant_types': grantTypes,
        'response_types': responseTypes,
        'token_endpoint_auth_method': authMethod,
        if (scopes != null) 'scope': scopes.join(' '),
      },
    );
  }

  /// The metadata of the server (RFC 8414 §2) of [metadata], as JSON: its
  /// endpoints, and what it supports, of [metadata] and of itself.
  Map<String, dynamic> metadataOf(ServerMetadata metadata) {
    String? url(Uri? uri) => uri?.toString();
    var grantTypes = {
      ...metadata.grantTypes,
      // The grant type of the `token` response type (RFC 7591 §2.1).
      if (metadata.responseTypes.contains('token')) 'implicit',
      if (metadata.deviceAuthorizationEndpoint != null) _deviceCodeGrantType,
      ...extensionGrants.keys,
    };
    var authMethods = metadata.clientAuthMethods.toList();
    return {
      'issuer': metadata.issuer.toString(),
      'authorization_endpoint': ?url(metadata.authorizationEndpoint),
      'token_endpoint': ?url(metadata.tokenEndpoint),
      'device_authorization_endpoint': ?url(
        metadata.deviceAuthorizationEndpoint,
      ),
      'revocation_endpoint': ?url(metadata.revocationEndpoint),
      'introspection_endpoint': ?url(metadata.introspectionEndpoint),
      'registration_endpoint': ?url(metadata.registrationEndpoint),
      'response_types_supported': metadata.responseTypes.toList(),
      'response_modes_supported': [
        if (metadata.responseTypes.contains('code')) 'query',
        if (metadata.responseTypes.contains('token')) 'fragment',
      ],
      'grant_types_supported': grantTypes.toList(),
      'code_challenge_methods_supported': [
        'S256',
        if (allowsPlainPkce) 'plain',
      ],
      if (metadata.tokenEndpoint != null)
        'token_endpoint_auth_methods_supported': authMethods,
      if (metadata.revocationEndpoint != null)
        'revocation_endpoint_auth_methods_supported': authMethods,
      if (metadata.introspectionEndpoint != null)
        'introspection_endpoint_auth_methods_supported': [
          for (var method in authMethods)
            if (method != 'none') method,
        ],
      if (metadata.scopes != null)
        'scopes_supported': metadata.scopes!.toList(),
      'service_documentation': ?url(metadata.serviceDocumentation),
      ...metadata.extra,
    };
  }

  /// A request handler of the metadata of the server (RFC 8414), of
  /// [metadataOf], which clients read to find its endpoints. Route a GET of
  /// [ServerMetadata.wellKnownPath] to it:
  ///
  /// ```dart
  /// var metadata = ServerMetadata(
  ///   issuer: Uri.parse('https://example.com'),
  ///   authorizationEndpoint: Uri.parse('https://example.com/oauth2/authorize'),
  ///   tokenEndpoint: Uri.parse('https://example.com/oauth2/token'),
  ///   grantTypes: ['authorization_code', 'refresh_token'],
  /// );
  /// app.get(metadata.wellKnownPath, server.metadataEndpoint(metadata));
  /// ```
  RequestHandler metadataEndpoint(ServerMetadata metadata) {
    var json = metadataOf(metadata);
    return (req, res) => json;
  }

  /// A request handler of device authorization requests (RFC 8628 §3.1),
  /// of a device that the user authorizes on another, which then polls the
  /// [tokenEndpoint] with the `device_code` of its response, by
  /// [exchangeDeviceCodeForToken]. Route a POST to it:
  ///
  /// ```dart
  /// router.post('/device', server.deviceAuthorizationEndpoint);
  /// ```
  ///
  /// Its client is authenticated as at the [tokenEndpoint]: a public one by
  /// its `client_id` alone, for which [verifyClient] is given `null`. It
  /// gives the [DeviceCodeResponse] of [requestDeviceCode], of the `scope` of
  /// the request, and errors as the [tokenEndpoint] does (RFC 8628 §3.2).
  Future deviceAuthorizationEndpoint(
    RequestContext req,
    ResponseContext res,
  ) async {
    var state = '';
    // Of its device code (RFC 8628 §3.2).
    res.headers
      ..['cache-control'] = 'no-store'
      ..['pragma'] = 'no-cache';

    try {
      var body = await _paramsOf(req, body: true);
      state = body['state']?.toString() ?? '';
      var (client, _) = await _authenticateClient(req, res, body, state);
      var scopes = await _getScopes(req, body: true);
      var response = await requestDeviceCode(client, scopes, req, res);
      return response.toJson();
    } on AngelHttpException {
      rethrow;
    } catch (e, st) {
      throw AuthorizationException(
        ErrorResponse(ErrorResponse.serverError, _internalServerError, state),
        error: e,
        statusCode: 500,
        stackTrace: st,
      );
    }
  }

  /// A request handler that either exchanges authorization codes for authorization tokens,
  /// or refreshes authorization tokens.
  Future tokenEndpoint(RequestContext req, ResponseContext res) async {
    var state = '';
    // Of its tokens, and of its errors (RFC 6749 §5.1).
    res.headers
      ..['cache-control'] = 'no-store'
      ..['pragma'] = 'no-cache';

    try {
      var body = await _paramsOf(req, body: true);

      state = body['state']?.toString() ?? '';

      req.container!.registerLazySingleton<Pkce>((_) {
        return Pkce.fromJson(req.bodyAsMap, state: state);
      });

      // Missing, or empty, is `invalid_request`; before the client is
      // authenticated, as is a grant that is not supported, which it need
      // not be to learn of either.
      var grantType = (await _getParam(req, 'grant_type', state, body: true))!;

      ExtensionGrant? extensionGrant;
      if (!_grantTypes.contains(grantType)) {
        extensionGrant =
            extensionGrants[grantType] ??
            (throw AuthorizationException(
              ErrorResponse(
                ErrorResponse.unsupportedGrantType,
                'Unsupported "grant_type" parameter: "$grantType".',
                state,
              ),
              statusCode: 400,
            ));
      }

      var (client, confidential) = await _authenticateClient(
        req,
        res,
        body,
        state,
      );

      AuthorizationTokenResponse response;
      if (grantType == _deviceCodeGrantType) {
        var deviceCode = await _getParam(req, 'device_code', state, body: true);
        response = await exchangeDeviceCodeForToken(
          client,
          deviceCode,
          state,
          req,
          res,
        );
      } else {
        if (grantType == 'authorization_code') {
          var code = await _getParam(req, 'code', state, body: true);
          // Required only if the authorization request gave one (RFC 6749
          // §4.1.3), which [exchangeAuthorizationCodeForToken] checks.
          var redirectUri = await _getParam(
            req,
            'redirect_uri',
            state,
            body: true,
            throwIfEmpty: false,
          );
          if (redirectUri != null && redirectUri.isEmpty) redirectUri = null;
          if (await requiresPkce(client)) {
            var verifier = _formValue(body, 'code_verifier');
            if (verifier == null || !_rgxPkce.hasMatch(verifier)) {
              throw AuthorizationException(
                ErrorResponse(
                  ErrorResponse.invalidRequest,
                  verifier == null
                      ? 'Missing "code_verifier" parameter; PKCE is required.'
                      : 'The "code_verifier" parameter must be of 43 to 128 '
                            'characters of A-Z, a-z, 0-9, "-", ".", "_" and '
                            '"~".',
                  state,
                ),
                statusCode: 400,
              );
            }
          }
          response = await exchangeAuthorizationCodeForToken(
            client,
            code,
            redirectUri,
            req,
            res,
          );
        } else if (grantType == 'refresh_token') {
          var refreshToken = await _getParam(
            req,
            'refresh_token',
            state,
            body: true,
          );
          var scopes = await _getScopes(req, body: true);
          response = await refreshAuthorizationToken(
            client,
            refreshToken,
            scopes,
            req,
            res,
          );
        } else if (grantType == 'password') {
          var username = await _getParam(req, 'username', state, body: true);
          var password = await _getParam(req, 'password', state, body: true);
          var scopes = await _getScopes(req, body: true);
          response = await resourceOwnerPasswordCredentialsGrant(
            client,
            username,
            password,
            scopes,
            req,
            res,
          );
        } else if (grantType == 'client_credentials') {
          // For confidential clients only (RFC 6749 §4.4): anyone may give
          // the id of a public client.
          if (!confidential) {
            throw AuthorizationException(
              ErrorResponse(
                ErrorResponse.unauthorizedClient,
                'A client without a secret may not use the client '
                'credentials grant.',
                state,
              ),
              statusCode: 400,
            );
          }
          var scopes = await _getScopes(req, body: true);
          response = await clientCredentialsGrant(client, scopes, req, res);
        } else {
          // Not of [_grantTypes], so of [extensionGrants].
          response = await extensionGrant!(req, res);
        }
      }

      var json = <String, dynamic>{'token_type': AuthorizationTokenType.bearer}
        ..addAll(response.toJson());
      // Of no refresh token (RFC 6749 §4.4.3), but of all else it gives.
      if (grantType == 'client_credentials') json.remove('refresh_token');
      return json;
    } on AngelHttpException {
      rethrow;
    } catch (e, st) {
      throw AuthorizationException(
        ErrorResponse(ErrorResponse.serverError, _internalServerError, state),
        error: e,
        statusCode: 500,
        stackTrace: st,
      );
    }
  }
}
