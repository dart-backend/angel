import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:logging/logging.dart';

import 'exception.dart';
import 'pkce.dart';
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
/// default of each grant method does: [error], `unsupported_grant_type` by
/// default, with the `state` of the form of [req].
Future<Never> _unsupportedGrant(
  RequestContext req,
  String description, {
  String error = ErrorResponse.unsupportedGrantType,
}) async {
  var body = await _paramsOf(req, body: true);
  throw AuthorizationException(
    ErrorResponse(error, description, body['state']?.toString() ?? ''),
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

  /// Verify that a [client] is the one identified by the [clientSecret].
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

    if (codeVerifier == null) {
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

  /// Prompt the currently logged-in user to grant or deny access to the [client].
  ///
  /// In many applications, this will entail showing a dialog to the user in question.
  ///
  /// If [implicit] is `true`, then the client is requesting an *implicit grant*.
  /// Be aware of the security implications of this - do not handle them exactly
  /// the same.
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

  /// Performs a client credentials grant. Only use this in situations where the client is 100% trusted.
  FutureOr<AuthorizationTokenResponse> clientCredentialsGrant(
    Client? client,
    RequestContext req,
    ResponseContext res,
  ) => _unsupportedGrant(req, 'Client credentials grants are not supported.');

  /// Performs a device code request, a request to the token endpoint
  /// without a `grant_type`.
  ///
  /// By default, it is `invalid_request`, as the `grant_type` is missing.
  FutureOr<DeviceCodeResponse> requestDeviceCode(
    Client client,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) => _unsupportedGrant(
    req,
    'Missing "grant_type" parameter; device code requests are not supported.',
    error: ErrorResponse.invalidRequest,
  );

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

    if (state != null) queryParameters['state'] = state;

    if (token.expiresIn != null) {
      queryParameters['expires_in'] = token.expiresIn.toString();
    }

    if (token.scope != null) queryParameters['scope'] = token.scope!.join(' ');

    var fragment = queryParameters.keys.fold<StringBuffer>(StringBuffer(), (
      buf,
      k,
    ) {
      if (buf.isNotEmpty) buf.write('&');
      return buf..write('$k=${Uri.encodeComponent(queryParameters[k]!)}');
    }).toString();

    return redirectUri.replace(fragment: fragment);
  }

  /// A request handler that invokes the correct logic, depending on which type
  /// of grant the client is requesting.
  Future<void> authorizationEndpoint(
    RequestContext req,
    ResponseContext res,
  ) async {
    var state = '';

    try {
      var query = req.queryParameters;
      state = query['state']?.toString() ?? '';
      var responseType = await _getParam(req, 'response_type', state);

      req.container!.registerLazySingleton<Pkce>((_) {
        return Pkce.fromJson(req.queryParameters, state: state);
      });

      if (responseType == 'code' || responseType == 'token') {
        // Ensure client ID
        var clientId = await _getParam(req, 'client_id', state);

        // Find client
        var client = await findClient(clientId);

        if (client == null) {
          throw AuthorizationException(
            ErrorResponse(
              ErrorResponse.unauthorizedClient,
              'Unknown client "$clientId".',
              state,
            ),
          );
        }

        // Grab redirect URI
        var redirectUri = await _getParam(req, 'redirect_uri', state);

        // Grab scopes
        var scopes = await _getScopes(req);

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

      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.invalidRequest,
          'Invalid or no "response_type" parameter provided',
          state,
        ),
        statusCode: 400,
      );
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

  /// A request handler that either exchanges authorization codes for authorization tokens,
  /// or refreshes authorization tokens.
  Future tokenEndpoint(RequestContext req, ResponseContext res) async {
    var state = '';

    try {
      var body = await req.parseBody().then((_) => req.bodyAsMap);

      state = body['state']?.toString() ?? '';

      req.container!.registerLazySingleton<Pkce>((_) {
        return Pkce.fromJson(req.bodyAsMap, state: state);
      });

      var grantType = await _getParam(
        req,
        'grant_type',
        state,
        body: true,
        throwIfEmpty: false,
      );
      // `grant_type=` is no grant type.
      if (grantType != null && grantType.isEmpty) grantType = null;

      ExtensionGrant? extensionGrant;
      if (grantType != null) {
        // Before the client is authenticated, which it need not be to learn
        // that its grant is not supported.
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
      }

      var (client, confidential) = await _authenticateClient(
        req,
        res,
        body,
        state,
      );

      if (grantType == null) {
        // A device code request.
        var scopes = await _getScopes(req, body: true);
        var deviceCodeResponse = await requestDeviceCode(
          client,
          scopes,
          req,
          res,
        );
        return deviceCodeResponse.toJson();
      }

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
          var redirectUri = await _getParam(
            req,
            'redirect_uri',
            state,
            body: true,
          );
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
          response = await clientCredentialsGrant(client, req, res);

          if (response.refreshToken != null) {
            // Remove refresh token
            response = AuthorizationTokenResponse(
              response.accessToken,
              expiresIn: response.expiresIn,
              scope: response.scope,
            );
          }
        } else {
          // Not of [_grantTypes], so of [extensionGrants].
          response = await extensionGrant!(req, res);
        }
      }

      return <String, dynamic>{'token_type': AuthorizationTokenType.bearer}
        ..addAll(response.toJson());
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
