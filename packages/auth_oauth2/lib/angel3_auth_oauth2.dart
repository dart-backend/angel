library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Cookie, SameSite;
import 'dart:math';

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:logging/logging.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

final _log = Logger('OAuth2Strategy');

/// The outcome of a callback: the user of [verifier], or the response of
/// [onError], which must never be taken for a user.
sealed class _Outcome {}

class _Verified extends _Outcome {
  final Object? user;
  _Verified(this.user);
}

class _Failed extends _Outcome {
  final Object? response;
  _Failed(this.response);
}

/// An Angel [AuthStrategy] that signs users in via a third-party service that speaks OAuth 2.0.
///
/// The same handler serves both legs of the flow, as `auth.authenticate(name)`
/// (or `auth.authenticate(name, options)` on the callback): a request with a
/// `code` or `error` query parameter is the provider's callback; any other
/// request is redirected to the provider.
///
/// Each login has its own random `state` (against login CSRF, RFC 6749
/// §10.12) and PKCE code verifier (RFC 7636), kept between the redirect and
/// the callback in a short-lived, signed, `HttpOnly`, `SameSite=Lax` cookie
/// scoped to the path of the redirect URI.
class OAuth2Strategy<User> implements AuthStrategy<User> {
  /// A callback that uses the third-party service to authenticate a [User].
  ///
  /// As always, return `null` if authentication fails. The client is closed
  /// once it returns, unless [httpClient] was given: keep the credentials,
  /// not the client.
  final FutureOr<User> Function(oauth2.Client, RequestContext, ResponseContext)
  verifier;

  /// A callback that is triggered when an OAuth2 error occurs (i.e. the user
  /// declines to login, or the callback is not that of a login started here:
  /// `invalid_state`, or malformed: `invalid_request`).
  ///
  /// It should write a response, or redirect; a value it returns (other than
  /// `null`) is serialized as the response.
  final FutureOr<dynamic> Function(
    oauth2.AuthorizationException,
    RequestContext,
    ResponseContext,
  )
  onError;

  /// The options defining how to connect to the third-party.
  final ExternalAuthOptions options;

  /// The URL to query to receive an authentication code.
  final Uri authorizationEndpoint;

  /// The URL to query to exchange an authentication code for a token.
  final Uri tokenEndpoint;

  /// An optional callback used to parse the response from a server who does not follow the OAuth 2.0 spec.
  final Map<String, dynamic> Function(MediaType?, String)? getParameters;

  /// An optional delimiter used to send requests to server who does not follow the OAuth 2.0 spec.
  final String delimiter;

  /// The HTTP client to exchange codes for tokens with, and of the clients
  /// given to [verifier]; by default, one of each login, closed after it.
  final http.Client? httpClient;

  /// The name of the cookies that keep the `state` and code verifier of
  /// logins: each login's is this, followed by `_` and the start of its
  /// `state`, so that logins in two tabs do not replace each other's.
  final String cookieName;

  /// The `SameSite` of the cookies of logins; default: [SameSite.lax], which
  /// a provider's redirect back (a GET) carries. A provider that posts its
  /// callback (`response_mode=form_post`, as Sign in with Apple) needs
  /// [SameSite.none], which browsers only keep over HTTPS.
  final SameSite cookieSameSite;

  /// How long a login may take between the redirect and the callback.
  final Duration loginTimeout;

  /// The key that signs the cookie; by default, derived from the client
  /// secret, so that every instance of the app signs alike, or random, for
  /// a client without a secret.
  final List<int> _cookieKey;

  final Random _random = Random.secure();

  OAuth2Strategy(
    this.options,
    this.authorizationEndpoint,
    this.tokenEndpoint,
    this.verifier,
    this.onError, {
    this.getParameters,
    this.delimiter = ' ',
    this.httpClient,
    this.cookieName = 'angel3_oauth2',
    this.cookieSameSite = SameSite.lax,
    this.loginTimeout = const Duration(minutes: 10),
    List<int>? cookieKey,
  }) : _cookieKey = cookieKey ?? _defaultCookieKey(options.clientSecret);

  /// The key of a client's [secret]: derived from it, or random without one,
  /// as a key derived from nothing would be that of every app.
  static List<int> _defaultCookieKey(String secret) {
    if (secret.isNotEmpty) {
      return sha256.convert(utf8.encode('angel3_auth_oauth2:$secret')).bytes;
    }
    _log.warning(
      'The OAuth2 client has no secret, so the cookies of logins are signed '
      'with a random key, which other instances of the app do not share: '
      'pass a cookieKey to run more than one.',
    );
    var random = Random.secure();
    return [for (var i = 0; i < 32; i++) random.nextInt(256)];
  }

  /// The name of the cookie of the login of [state].
  String _cookieNameOf(String state) =>
      '${cookieName}_${state.substring(0, 12)}';

  oauth2.AuthorizationCodeGrant _createGrant(String codeVerifier) =>
      oauth2.AuthorizationCodeGrant(
        options.clientId,
        authorizationEndpoint,
        tokenEndpoint,
        secret: options.clientSecret,
        delimiter: delimiter,
        getParameters: getParameters,
        httpClient: httpClient,
        codeVerifier: codeVerifier,
      );

  /// The parameters of the provider's response: of the query, and, of a
  /// callback that is posted (`response_mode=form_post`), of its form.
  static Future<Map<String, String>> _parametersOf(RequestContext req) async {
    var parameters = {...?req.uri?.queryParameters};
    if (req.method == 'POST') {
      try {
        await req.parseBody();
        for (var MapEntry(:key, :value) in req.bodyAsMap.entries) {
          if (value is String) parameters[key] = value;
        }
      } on FormatException {
        // Not a form: of the query alone.
      }
    }
    return parameters;
  }

  /// Whether [parameters] are those of the provider's callback, rather than
  /// of the start of a login.
  static bool _isCallback(Map<String, String> parameters) =>
      parameters.containsKey('code') || parameters.containsKey('error');

  @override
  FutureOr<User?> authenticate(
    RequestContext req,
    ResponseContext res, [
    AngelAuthOptions<User>? options,
  ]) async {
    var parameters = await _parametersOf(req);
    if (_isCallback(parameters)) {
      switch (await _callback(req, res, parameters)) {
        case _Verified(:var user):
          return user as User?;
        case _Failed(:var response):
          // The response of [onError], if it gave one, but never a user.
          if (response != null && res.isOpen) await res.serialize(response);
          return null;
      }
    }

    await res.redirect(_startLogin(res));
    return null;
  }

  /// The URL that starts a login at the provider, whose `state` and code
  /// verifier are kept in a cookie of [res].
  Uri _startLogin(ResponseContext res) {
    var state = _randomString(32);
    var verifier = _randomString(64);
    var url = _createGrant(verifier).getAuthorizationUrl(
      options.redirectUri,
      scopes: options.scopes,
      state: state,
    );

    res.cookies.add(
      _cookie(
        _cookieNameOf(state),
        _sign({
          's': state,
          'v': verifier,
          't': DateTime.now().millisecondsSinceEpoch,
        }),
      )..maxAge = loginTimeout.inSeconds,
    );
    return url;
  }

  /// The endpoint that is invoked by the third-party after successful authentication.
  ///
  /// Returns the result of [verifier], or of [onError] if the provider sent
  /// an error, the callback is not of a login started by this strategy
  /// (`invalid_state`), or it is malformed (`invalid_request`). Throws a 502
  /// if the provider cannot be reached.
  Future<dynamic> authenticateCallback(
    RequestContext req,
    ResponseContext res, [
    AngelAuthOptions? options,
  ]) async => switch (await _callback(req, res, await _parametersOf(req))) {
    _Verified(:var user) => user,
    _Failed(:var response) => response,
  };

  Future<_Outcome> _callback(
    RequestContext req,
    ResponseContext res,
    Map<String, String> query,
  ) async {
    var state = query['state'];
    var login = state == null || state.length < 12
        ? null
        : _readLogin(req, state);
    if (state != null && state.length >= 12) {
      // Used once: a new login needs a new state.
      res.cookies.add(
        _cookie(_cookieNameOf(state), '')
          ..maxAge = 0
          ..expires = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }

    if (login == null || state != login.state) {
      return _Failed(
        await onError(
          oauth2.AuthorizationException(
            'invalid_state',
            'The login expired, or was not started here.',
            null,
          ),
          req,
          res,
        ),
      );
    }

    var grant = _createGrant(login.verifier)
      ..getAuthorizationUrl(
        options.redirectUri,
        scopes: options.scopes,
        state: login.state,
      );

    oauth2.Client client;
    try {
      client = await grant.handleAuthorizationResponse(query);
    } on oauth2.AuthorizationException catch (e) {
      return _Failed(await onError(e, req, res));
    } on FormatException catch (e) {
      return _Failed(
        await onError(
          oauth2.AuthorizationException('invalid_request', e.message, null),
          req,
          res,
        ),
      );
    } on http.ClientException catch (e) {
      throw AngelHttpException(
        statusCode: 502,
        message: 'The OAuth2 provider could not be reached.',
        error: e,
      );
    }

    try {
      return _Verified(await verifier(client, req, res));
    } finally {
      // Its HTTP client is ours, unless it was given.
      if (httpClient == null) client.close();
    }
  }

  /// The `state` and code verifier of the login of [req]'s cookie, if it has
  /// one that this strategy signed, and that has not timed out.
  ({String state, String verifier})? _readLogin(
    RequestContext req,
    String state,
  ) {
    var name = _cookieNameOf(state);
    var value = req.cookies
        .where((c) => c.name == name)
        .map((c) => c.value)
        .firstOrNull;
    if (value == null) return null;
    var dot = value.lastIndexOf('.');
    if (dot < 0) return null;
    var data = value.substring(0, dot), signature = value.substring(dot + 1);
    if (!_constantTimeEquals(signature, _signatureOf(data))) return null;
    try {
      var claims = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(data))),
      );
      if (claims is! Map) return null;
      var (state, verifier, time) = (claims['s'], claims['v'], claims['t']);
      if (state is! String || verifier is! String || time is! int) return null;
      var started = DateTime.fromMillisecondsSinceEpoch(time);
      if (DateTime.now().difference(started) > loginTimeout) return null;
      return (state: state, verifier: verifier);
    } on FormatException {
      return null;
    }
  }

  String _sign(Map<String, Object> claims) {
    var data = _unpadded(base64Url.encode(utf8.encode(json.encode(claims))));
    return '$data.${_signatureOf(data)}';
  }

  String _signatureOf(String data) => _unpadded(
    base64Url.encode(
      Hmac(sha256, _cookieKey).convert(ascii.encode(data)).bytes,
    ),
  );

  /// [base64] without its `=` padding, which a cookie value may not keep.
  static String _unpadded(String base64) => base64.replaceAll('=', '');

  /// The cookie of a login: sent only to the callback, and only over HTTPS
  /// if the redirect URI is.
  Cookie _cookie(String name, String value) => Cookie(name, value)
    ..httpOnly = true
    ..secure = options.redirectUri.scheme == 'https'
    ..sameSite = cookieSameSite
    ..path = options.redirectUri.path.isEmpty ? '/' : options.redirectUri.path;

  /// A random string of the characters of a PKCE code verifier (RFC 7636).
  String _randomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    return String.fromCharCodes([
      for (var i = 0; i < length; i++)
        chars.codeUnitAt(_random.nextInt(chars.length)),
    ]);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
