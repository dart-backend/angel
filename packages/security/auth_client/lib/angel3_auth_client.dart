library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Cookie, IOException, SameSite;
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
  /// As always, return `null` if authentication fails, as of a user that
  /// the app refuses: [AngelAuth.authenticate] then tries its next strategy,
  /// or answers a 401, or redirects to its `failureRedirect`. The client is
  /// of the strategy's HTTP client, which every login shares: do not close
  /// it.
  final FutureOr<User?> Function(oauth2.Client, RequestContext, ResponseContext)
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
  /// given to [verifier]; by default, one of the strategy, which every login
  /// shares, so that its connections to the provider are kept, and which is
  /// never closed.
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

  /// The path of the cookies of logins, which must be that of the redirect
  /// URI or above it, so that the callback is sent them; by default, the
  /// path that the route that starts a login shares with the redirect URI,
  /// so that the start is sent them too.
  ///
  /// Behind a proxy that maps another path to the app's, such as
  /// `https://host/app/auth/github` to `/auth/github`, the path the app sees
  /// is not the browser's: give the browser's, such as `/app/auth/github`,
  /// or the cookies are of `/`, and sent to every app of the host.
  ///
  /// Give one that covers the route that starts a login too, which is then
  /// sent the cookies, so that it expires those beyond [maxLogins]: of one
  /// of the redirect URI alone, only the callback does.
  final String? cookiePath;

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
    this.cookiePath,
    List<int>? cookieKey,
  }) : _cookieKey = cookieKey ?? _defaultCookieKey(options.clientSecret) {
    // Of a key that anyone could guess, of which login cookies are forged,
    // as of one of an unset variable of the environment.
    if (cookieKey != null && cookieKey.length < 16) {
      throw ArgumentError.value(
        '${cookieKey.length} bytes',
        'cookieKey',
        'must be of at least 16 bytes',
      );
    }
    try {
      // Of the characters a cookie's name may have, as dart:io checks.
      Cookie(_cookieNameOf('a' * 12), '');
    } on FormatException catch (e) {
      throw ArgumentError.value(cookieName, 'cookieName', e.message);
    }
    if (cookiePath case var path?) {
      if (!path.startsWith('/')) {
        throw ArgumentError.value(path, 'cookiePath', 'must start with "/"');
      }
      try {
        // Of the characters a cookie's path may have, as dart:io checks.
        Cookie('x', '').path = path;
      } on FormatException catch (e) {
        throw ArgumentError.value(path, 'cookiePath', e.message);
      }
      if (!_pathMatches(_redirectPath, path)) {
        _log.warning(
          'The cookiePath $path is not the redirect URI\'s path, or above it: '
          'the callback is not sent the cookies of logins, and every login '
          'fails.',
        );
      }
    }
    if (maxLogins < 1) {
      throw ArgumentError.value(maxLogins, 'maxLogins', 'must be at least 1');
    }
    // Of the whole seconds of the cookie's Max-Age, of which 0 is dropped.
    if (loginTimeout < const Duration(seconds: 1)) {
      throw ArgumentError.value(
        loginTimeout,
        'loginTimeout',
        'must be at least a second',
      );
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
      'with a random key of this strategy, which no other shares, as of '
      'another instance of the app, or another isolate of it: pass a '
      'cookieKey to run more than one.',
    );
    var random = Random.secure();
    return [for (var i = 0; i < 32; i++) random.nextInt(256)];
  }

  /// The name of the cookie of the login of [state].
  String _cookieNameOf(String state) =>
      '${cookieName}_${state.substring(0, 12)}';

  /// The HTTP client of every grant: [httpClient], or one of the strategy,
  /// created once it is needed, which a verifier that closes its client
  /// does not close.
  late final http.Client _client = httpClient ?? _Unclosable(http.Client());

  /// The grant of a login of [codeVerifier], of the strategy's [_client],
  /// which it does not close.
  oauth2.AuthorizationCodeGrant _createGrant(String codeVerifier) =>
      oauth2.AuthorizationCodeGrant(
        options.clientId,
        _authorizationUrl,
        tokenEndpoint,
        // None for a client without one, as of PKCE alone, which sends
        // only its id, rather than an empty secret.
        secret: options.clientSecret.isEmpty ? null : options.clientSecret,
        basicAuth: basicAuth,
        delimiter: delimiter,
        getParameters: getParameters,
        httpClient: _client,
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
  ///
  /// The fields of a posted form are of a callback, if [callback], as of
  /// [authenticateCallback], if [_postsCallbacks], or if it has a `state`,
  /// which a callback always has: else, as of a form that starts a login,
  /// such as one of a field named `code`, they are not the provider's.
  Future<(Map<String, String>, String?)> _parametersOf(
    RequestContext req, {
    bool callback = false,
  }) async {
    var parameters = {...?req.uri?.queryParameters};
    if (req.method == 'POST') {
      try {
        await req.parseBody();
        var body = req.bodyAsMap;
        if (callback || _postsCallbacks || body['state'] is String) {
          for (var MapEntry(:key, :value) in body.entries) {
            if (value is String) parameters[key] = value;
          }
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
  late final bool _postsCallbacks =
      (authorizationParameters['response_mode'] ??
          authorizationEndpoint.queryParameters['response_mode']) ==
      'form_post';

  /// The failure of [req] of the OAuth2 [error], of [description], and of
  /// [uri], as [onError] answers it.
  Future<_Outcome> _fail(
    String error,
    String? description,
    RequestContext req,
    ResponseContext res, {
    Uri? uri,
  }) async => _Failed(
    await onError(
      oauth2.AuthorizationException(error, description, uri),
      req,
      res,
    ),
  );

  /// The failure of a request whose body cannot be read, for [unreadable].
  Future<_Outcome> _unreadable(
    RequestContext req,
    ResponseContext res,
    String unreadable,
  ) => _fail(
    'invalid_request',
    'The body of the request cannot be read: $unreadable',
    req,
    res,
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
        if (response != null && res.isOpen) {
          await res.serialize(response);
        } else if (res.isOpen &&
            ((res.buffer?.isNotEmpty ?? false) || res.headersSent)) {
          // Of a body that [onError] wrote, to the buffer or as a stream,
          // but did not close: answered, so that [AngelAuth] does not answer
          // it again, nor try another.
          await res.close();
        }
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
    var url = _createGrant(verifier).getAuthorizationUrl(
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

    var path =
        cookiePath ??
        _sharedPath(req.uri?.path ?? '/', options.redirectUri.path);
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
        // Of whole seconds, rounded up, so that the browser keeps it as long
        // as the server takes the login.
      )..maxAge = (loginTimeout.inMilliseconds / 1000).ceil(),
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
    var (parameters, unreadable) = await _parametersOf(req, callback: true);
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
    var decoded = value == null ? null : _decodeLogin(value);
    // Of this state alone: the cookie is found by its start, which another
    // state may share, whose callback must not end this login.
    var stored = decoded?.state == state ? decoded : null;
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
      // Of the cookie of this login alone, which was expired: one of another
      // state, of the same start, is counted.
      except: stored != null ? name : null,
    );

    if (login == null) {
      return _fail(
        'invalid_state',
        'The login expired, or was not started here.',
        req,
        res,
      );
    }

    // An error of the provider, as when the user refuses, which is
    // answered here, so that no part of the callback is read by the grant,
    // of which a FormatException is then of the token response alone.
    if (query['error'] case var error?) {
      var uri = query['error_uri'];
      return _fail(
        error,
        query['error_description'],
        req,
        res,
        // Of none, if it is not a URI, which the error is of all the same.
        uri: uri == null ? null : Uri.tryParse(uri),
      );
    }
    // Of a provider that gave no error, a code is required: else, the
    // callback is malformed, which is the client's.
    if ((query['code'] ?? '').isEmpty) {
      return _fail(
        'invalid_request',
        'The callback has no "code" parameter.',
        req,
        res,
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
      switch (e) {
        case oauth2.AuthorizationException():
          // Of an error of the token endpoint, as `invalid_grant`.
          return _Failed(await onError(e, req, res));
        case FormatException():
          // Of the provider's token response, as the callback was read here:
          // an error page of its own, as of an outage, is the provider's.
          throw AngelHttpException(
            statusCode: 502,
            message: "The OAuth2 provider's token response cannot be read.",
            error: e,
          );
        // Of the network, as of a bad certificate, or of no answer in time.
        case http.ClientException() || IOException() || TimeoutException():
          throw AngelHttpException(
            statusCode: 502,
            message: 'The OAuth2 provider could not be reached.',
            error: e,
          );
      }
      rethrow;
    }

    return _Verified(await verifier(client, req, res));
  }

  /// Whether a login that was [started], in milliseconds since the epoch,
  /// has taken longer than [loginTimeout].
  ///
  /// So is one that was started more than [loginTimeout] ahead of now, as of
  /// an instance whose clock is ahead, which would else be taken until the
  /// browser drops its cookie.
  bool _timedOut(int started) =>
      DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(started))
          .abs() >
      loginTimeout;

  /// Whether a cookie of [cookiePath] is sent to [path] (RFC 6265 §5.1.4).
  static bool _pathMatches(String path, String cookiePath) =>
      path == cookiePath ||
      (path.startsWith(cookiePath) &&
          (cookiePath.endsWith('/') || path[cookiePath.length] == '/'));

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
      // UTF-8, of the same bytes as ASCII, of a value that is not of it.
      Hmac(sha256, _cookieKey).convert(utf8.encode(data)).bytes,
    ),
  );

  /// [base64] without its `=` padding, which a cookie value may not keep.
  static String _unpadded(String base64) => base64.replaceAll('=', '');

  /// The cookie that expires that of [name], of [path], which it must be
  /// of to replace it.
  Cookie _expired(String name, String path) => _cookie(name, '', path)
    ..maxAge = 0
    ..expires = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

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

/// An HTTP client that is not closed by [close], of the strategy's own,
/// which every login shares, as a verifier may close the client it is given.
class _Unclosable extends http.BaseClient {
  final http.Client _inner;

  _Unclosable(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {}
}
