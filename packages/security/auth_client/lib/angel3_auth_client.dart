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

/// What the default key of the cookies of logins is derived from, before
/// the client secret. Of the package's former name, `angel3_auth_oauth2`,
/// and kept so: another would refuse the cookies of logins in progress, as
/// during a deploy.
const _cookieKeyPrefix = 'angel3_auth_oauth2:';

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
/// scoped to the path that the start of the login and the redirect URI
/// share.
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

  /// Whether the client ID and secret are sent to the token endpoint with
  /// HTTP Basic authentication (`client_secret_basic`), as by default; or,
  /// if `false`, as `client_id` and `client_secret` in the form of the
  /// request (`client_secret_post`), as some providers require.
  final bool basicAuth;

  /// More query parameters of the authorization URL, such as
  /// `access_type: 'offline'` (for a refresh token of Google), `prompt`, or
  /// `response_mode: 'form_post'` (of Sign in with Apple, with
  /// [cookieSameSite] of [SameSite.none]).
  ///
  /// They do not replace the parameters of the strategy: `response_type`,
  /// `client_id`, `redirect_uri`, `scope`, `state` and those of PKCE.
  final Map<String, String> authorizationParameters;

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

  /// How many logins of a browser may be in progress at once, each of a
  /// cookie that the callback is sent; starting another expires the
  /// cookies of the oldest. Default: 5.
  final int maxLogins;

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
    this.basicAuth = true,
    this.authorizationParameters = const {},
    this.httpClient,
    this.cookieName = 'angel3_oauth2',
    this.cookieSameSite = SameSite.lax,
    this.loginTimeout = const Duration(minutes: 10),
    this.maxLogins = 5,
    List<int>? cookieKey,
  }) : _cookieKey = cookieKey ?? _defaultCookieKey(options.clientSecret) {
    if (maxLogins < 1) {
      throw ArgumentError.value(maxLogins, 'maxLogins', 'must be at least 1');
    }
    // Of settings with which every login fails, or which are dropped.
    if (_postsCallbacks && cookieSameSite != SameSite.none) {
      _log.warning(
        'With response_mode=form_post, the provider posts its callback '
        'across sites, which a cookie of SameSite.$cookieSameSite is not '
        'sent with: every login fails. Pass cookieSameSite: SameSite.none, '
        'over HTTPS.',
      );
    }
    if (cookieSameSite == SameSite.none &&
        options.redirectUri.scheme != 'https') {
      _log.warning(
        'A cookie of SameSite.none must be Secure, which it is only of an '
        'https redirect URI: browsers drop it, and every login fails.',
      );
    }
    var dropped = [
      for (var key in authorizationParameters.keys)
        if (_ownParameters.contains(key)) key,
    ];
    if (dropped.isNotEmpty) {
      _log.warning(
        'The authorizationParameters ${dropped.join(', ')} are dropped, as '
        'the strategy gives them itself: set scopes in the '
        'ExternalAuthOptions instead.',
      );
    }
  }

  /// The key of a client's [secret]: derived from it, or random without one,
  /// as a key derived from nothing would be that of every app.
  static List<int> _defaultCookieKey(String secret) {
    if (secret.isNotEmpty) {
      return sha256.convert(utf8.encode('$_cookieKeyPrefix$secret')).bytes;
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

  /// An HTTP client that is never used, of the grants that only build an
  /// authorization URL, so that none is created, and closed, for each.
  static final http.Client _idleClient = http.Client();

  /// The grant of a login of [codeVerifier], of [client] if given, as of
  /// one that makes no request, else of [httpClient], or one of its own.
  oauth2.AuthorizationCodeGrant _createGrant(
    String codeVerifier, {
    http.Client? client,
  }) => oauth2.AuthorizationCodeGrant(
    options.clientId,
    _authorizationUrl,
    tokenEndpoint,
    // None for a client without one, as of PKCE alone, which sends
    // only its id, rather than an empty secret.
    secret: options.clientSecret.isEmpty ? null : options.clientSecret,
    basicAuth: basicAuth,
    delimiter: delimiter,
    getParameters: getParameters,
    httpClient: client ?? httpClient,
    codeVerifier: codeVerifier,
  );

  /// [authorizationEndpoint], with [authorizationParameters] but those of
  /// the strategy, which the grant adds.
  late final Uri _authorizationUrl = authorizationParameters.isEmpty
      ? authorizationEndpoint
      : authorizationEndpoint.replace(
          queryParameters: {
            ...authorizationEndpoint.queryParameters,
            for (var MapEntry(:key, :value) in authorizationParameters.entries)
              if (!_ownParameters.contains(key)) key: value,
          },
        );

  /// The parameters that [authorizationEndpoint] repeats, but those of the
  /// strategy, and those that [authorizationParameters] replace.
  late final Map<String, List<String>> _repeatedParameters = {
    for (var MapEntry(:key, :value)
        in authorizationEndpoint.queryParametersAll.entries)
      if (value.length > 1 &&
          !_ownParameters.contains(key) &&
          !authorizationParameters.containsKey(key))
        key: value,
  };

  /// The parameters of the authorization URL that the strategy gives, which
  /// [authorizationParameters] do not replace: `scope` too, which it leaves
  /// out without scopes.
  static const _ownParameters = {
    'response_type',
    'client_id',
    'redirect_uri',
    'scope',
    'state',
    'code_challenge',
    'code_challenge_method',
  };

  /// The parameters of the provider's response: of the query, and, of a
  /// callback that is posted (`response_mode=form_post`), of its form; and
  /// why a posted body cannot be read, as of a malformed, too large, or not
  /// UTF-8 form, if it cannot, of which the parameters are of the query.
  static Future<(Map<String, String>, String?)> _parametersOf(
    RequestContext req,
  ) async {
    var parameters = {...?req.uri?.queryParameters};
    if (req.method == 'POST') {
      try {
        await req.parseBody();
        for (var MapEntry(:key, :value) in req.bodyAsMap.entries) {
          if (value is String) parameters[key] = value;
        }
      } on FormatException catch (e) {
        return (parameters, e.message);
      } on AngelHttpException catch (e) {
        // The framework's 400 or 413 of a body it cannot read.
        if (e.statusCode < 400 || e.statusCode >= 500) rethrow;
        return (parameters, e.message);
      }
    }
    return (parameters, null);
  }

  /// Whether the provider posts its callback, of `response_mode=form_post`,
  /// so that a body that cannot be read is of a callback.
  ///
  /// Of [authorizationParameters], or of the query of
  /// [authorizationEndpoint], as it was asked for before them.
  bool get _postsCallbacks =>
      (authorizationParameters['response_mode'] ??
          authorizationEndpoint.queryParameters['response_mode']) ==
      'form_post';

  /// The failure of a request whose body cannot be read, for [unreadable].
  Future<_Outcome> _unreadable(
    RequestContext req,
    ResponseContext res,
    String unreadable,
  ) async => _Failed(
    await onError(
      oauth2.AuthorizationException(
        'invalid_request',
        'The body of the request cannot be read: $unreadable',
        null,
      ),
      req,
      res,
    ),
  );

  /// The outcome of [req], of [authenticate]: of its callback, or `null` of
  /// the start of a login. A body that cannot be read is of a callback, to
  /// [onError] as `invalid_request`, only if [_postsCallbacks]: else, as of
  /// a form that starts a login, it is of the query alone.
  Future<_Outcome?> _outcomeOf(RequestContext req, ResponseContext res) async {
    var (parameters, unreadable) = await _parametersOf(req);
    if (unreadable != null && _postsCallbacks) {
      return _unreadable(req, res, unreadable);
    }
    if (!_isCallback(parameters)) return null;
    return _callback(req, res, parameters);
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
    switch (await _outcomeOf(req, res)) {
      case _Verified(:var user):
        return user as User?;
      case _Failed(:var response):
        // The response of [onError], if it gave one, but never a user.
        if (response != null && res.isOpen) await res.serialize(response);
        return null;
      case null:
        await res.redirect(_startLogin(req, res));
        return null;
    }
  }

  /// The URL that starts a login at the provider, whose `state` and code
  /// verifier are kept in a cookie of [res]. Of the logins of [req] that
  /// were started before, only the newest are kept, so that their cookies,
  /// which the callback is sent, stay few.
  Uri _startLogin(RequestContext req, ResponseContext res) {
    var state = _randomString(32);
    var verifier = _randomString(64);
    // Of no request, so of a client that is never used.
    var url = _createGrant(verifier, client: _idleClient).getAuthorizationUrl(
      options.redirectUri,
      scopes: options.scopes,
      state: state,
    );
    // Of all values of a parameter that the endpoint repeats, of which
    // `package:oauth2` keeps only the last.
    if (_repeatedParameters.isNotEmpty) {
      url = url.replace(
        queryParameters: <String, Object>{
          ...url.queryParametersAll,
          ..._repeatedParameters,
        },
      );
    }

    // Of the newest logins but this one, which the start of a login is sent
    // too, as its cookie is of the path it shares with the callback.
    _expireOlderLogins(req, res, keep: maxLogins - 1);

    var path = _sharedPath(req.uri?.path ?? '/', options.redirectUri.path);
    res.cookies.add(
      _cookie(
        _cookieNameOf(state),
        _sign({
          's': state,
          'v': verifier,
          't': DateTime.now().millisecondsSinceEpoch,
          'p': path,
          'c': options.clientId,
        }),
        path,
      )..maxAge = loginTimeout.inSeconds,
    );
    return url;
  }

  /// Expires the cookies of the logins of [req] that this strategy signed,
  /// but the [keep] newest, and that of [except].
  void _expireOlderLogins(
    RequestContext req,
    ResponseContext res, {
    required int keep,
    String? except,
  }) {
    var logins = [
      for (var cookie in req.cookies)
        if (cookie.name.startsWith('${cookieName}_') && cookie.name != except)
          if (_decodeLogin(cookie.value) case var login?)
            (name: cookie.name, login: login),
    ]..sort((a, b) => b.login.started.compareTo(a.login.started));
    for (var (:name, :login) in logins.skip(max(0, keep))) {
      _log.fine('Expiring the cookie of an older login, of ${login.started}');
      res.cookies.add(_expired(name, login.path));
    }
  }

  /// The longest path of whole segments that [a] and [b] share, so that a
  /// cookie of it is sent to both: `/auth/github`, of `/auth/github` and
  /// `/auth/github/callback`; or `/`.
  static String _sharedPath(String a, String b) {
    List<String> segments(String path) => [
      for (var segment in path.split('/'))
        if (segment.isNotEmpty) segment,
    ];
    var (x, y) = (segments(a), segments(b));
    var shared = <String>[];
    for (var i = 0; i < min(x.length, y.length) && x[i] == y[i]; i++) {
      shared.add(x[i]);
    }
    return '/${shared.join('/')}';
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
  ]) async {
    var (parameters, unreadable) = await _parametersOf(req);
    var outcome = unreadable != null
        ? await _unreadable(req, res, unreadable)
        : await _callback(req, res, parameters);
    return switch (outcome) {
      _Verified(:var user) => user,
      _Failed(:var response) => response,
    };
  }

  Future<_Outcome> _callback(
    RequestContext req,
    ResponseContext res,
    Map<String, String> query,
  ) async {
    var state = query['state'];
    // Of the form of a state of this strategy, else of no login: of any
    // other, as of a crafted link, the name of its cookie may not be valid.
    var ours = state != null && _rgxState.hasMatch(state);
    var name = ours ? _cookieNameOf(state) : null;
    var value = name == null
        ? null
        : req.cookies.where((c) => c.name == name).firstOrNull?.value;
    // The login of the cookie, if this strategy signed it, timed out or not.
    var stored = value == null ? null : _decodeLogin(value);
    if (stored != null) {
      // Used once, or refused: a new login needs a new state.
      res.cookies.add(_expired(name!, stored.path));
    }
    var login = stored != null && !_timedOut(stored.started) ? stored : null;
    // Of the logins that are kept: of one that is done, as when they were
    // started, but the newest; else, as of a callback of no login of this
    // browser, which must not expire those in progress, at most maxLogins.
    _expireOlderLogins(
      req,
      res,
      keep: login != null ? maxLogins - 1 : maxLogins,
      except: name,
    );

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
    } catch (e) {
      // Of any failure, its HTTP client is ours, unless it was given.
      _closeGrant(grant);
      switch (e) {
        case oauth2.AuthorizationException():
          return _Failed(await onError(e, req, res));
        case FormatException():
          return _Failed(
            await onError(
              oauth2.AuthorizationException('invalid_request', e.message, null),
              req,
              res,
            ),
          );
        case http.ClientException():
          throw AngelHttpException(
            statusCode: 502,
            message: 'The OAuth2 provider could not be reached.',
            error: e,
          );
      }
      rethrow;
    }

    try {
      return _Verified(await verifier(client, req, res));
    } finally {
      // The grant's client, which is the client's.
      _closeGrant(grant);
    }
  }

  /// Whether a login that was [started], in milliseconds since the epoch,
  /// has taken longer than [loginTimeout].
  bool _timedOut(int started) =>
      DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(started)) >
      loginTimeout;

  /// The login of a cookie's [value], if this strategy signed it: its
  /// `state`, code verifier, when it was started, in milliseconds, and the
  /// path of its cookie, which one of before 10.0.0's release had not, of
  /// the redirect URI.
  ({String state, String verifier, int started, String path})? _decodeLogin(
    String value,
  ) {
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
      // Of a strategy of another client, of the same cookie name and key;
      // of none, of a cookie of 10.0.0, which had not it.
      var client = claims['c'];
      if (client != null && client != options.clientId) return null;
      var path = claims['p'];
      return (
        state: state,
        verifier: verifier,
        started: time,
        path: path is String ? path : _redirectPath,
      );
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

  /// The cookie that expires that of [name], of [path], which it must be
  /// of to replace it.
  Cookie _expired(String name, String path) => _cookie(name, '', path)
    ..maxAge = 0
    ..expires = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// Closes the HTTP client of [grant], of a token exchange that failed,
  /// unless it was given.
  void _closeGrant(oauth2.AuthorizationCodeGrant grant) {
    if (httpClient == null) grant.close();
  }

  /// A `state` of this strategy, of [_randomString].
  static final _rgxState = RegExp(r'^[A-Za-z0-9\-._~]{32}$');

  /// The cookie of a login, of [path]: only over HTTPS if the redirect URI
  /// is.
  Cookie _cookie(String name, String value, String path) => Cookie(name, value)
    ..httpOnly = true
    ..secure = options.redirectUri.scheme == 'https'
    ..sameSite = cookieSameSite
    ..path = path;

  /// The path of the redirect URI, of the cookies of logins before it was
  /// that which the start of a login shares with it.
  String get _redirectPath =>
      options.redirectUri.path.isEmpty ? '/' : options.redirectUri.path;

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
