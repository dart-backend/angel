import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

import 'auth_token.dart';
import 'options.dart';
import 'strategy.dart';

/// Handles authentication within an Angel application.
class AngelAuth<User> {
  final _log = Logger('AngelAuth');

  late Hmac _hs256;
  late int _jwtLifeSpan;

  // Broadcast, so that what no one listens to is not kept.
  final StreamController<User> _onLogin = StreamController<User>.broadcast(),
      _onLogout = StreamController<User>.broadcast();
  final Random _random = Random.secure();
  final RegExp _rgxBearer = RegExp(r'^Bearer\s+(.+)$', caseSensitive: false);

  /// The default of `jwtLifeSpan`: one day, in milliseconds.
  static final int defaultJwtLifeSpan = const Duration(days: 1).inMilliseconds;

  /// If `true` (default), then JWT's will be stored and retrieved from a `token` cookie.
  final bool allowCookie;

  /// If `true` (default: `false`), then users can include a JWT in the query
  /// string as `token`.
  ///
  /// A query string ends up in the logs of servers and proxies, the browser's
  /// history and `Referer` headers, so enable this only where a JWT cannot be
  /// sent otherwise, as by a browser opening a WebSocket.
  final bool allowTokenInQuery;

  /// Whether emitted cookies should have the `secure` and `HttpOnly` flags,
  /// as well as being restricted to a specific domain.
  final bool secureCookies;

  /// A domain to restrict emitted cookies to.
  ///
  /// Only applies if [allowCookie] is `true`.
  final String? cookieDomain;

  /// A path to restrict emitted cookies to.
  ///
  /// Only applies if [allowCookie] is `true`.
  final String cookiePath;

  /// The `SameSite` attribute of emitted cookies; default: [SameSite.lax],
  /// so that other sites' requests (as a form posted to the app) do not
  /// carry the JWT. `null` sets none.
  ///
  /// Only applies if [allowCookie] is `true`.
  final SameSite? cookieSameSite;

  /// If `true` (default), then JWT's will be considered invalid if used from a different IP than the first user's it was issued to.
  ///
  /// This is a security provision. Even if a user's JWT is stolen, a remote attacker will not be able to impersonate anyone.
  final bool enforceIp;

  /// The endpoint to mount [reviveJwt] at. If `null`, then no revival route is mounted. Default: `/auth/token`.
  String reviveTokenEndpoint;

  /// How long after a JWT has expired it may still be revived at
  /// [reviveTokenEndpoint]; default: none, so only a JWT that is still
  /// valid is exchanged for a new one.
  final Duration reviveGracePeriod;

  /// A set of [AuthStrategy] instances used to authenticate users.
  Map<String, AuthStrategy<User>> strategies = {};

  /// Serializes a user into a unique identifier associated only with one identity.
  FutureOr<String> Function(User) serializer;

  /// Deserializes a unique identifier into its associated identity. In most cases, this is a user object or model instance.
  FutureOr<User> Function(String) deserializer;

  /// Fires the result of [deserializer] whenever a user signs in to the
  /// application, to those listening then.
  Stream<User> get onLogin => _onLogin.stream;

  /// Fires `req.user`, which is usually the result of [deserializer],
  /// whenever a user signs out of the application, to those listening then.
  Stream<User> get onLogout => _onLogout.stream;

  /// The [Hmac] being used to encode JWT's.
  Hmac get hmac => _hs256;

  String _randomString({
    int length = 32,
    String validChars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_',
  }) {
    var chars = <int>[];
    while (chars.length < length) {
      chars.add(validChars.codeUnitAt(_random.nextInt(validChars.length)));
    }
    return String.fromCharCodes(chars);
  }

  /// `jwtLifeSpan` - should be in *milliseconds*; default:
  /// [defaultJwtLifeSpan], one day. `-1` makes JWTs valid for ever.
  AngelAuth({
    String? jwtKey,
    required this.serializer,
    required this.deserializer,
    num? jwtLifeSpan,
    this.allowCookie = true,
    this.allowTokenInQuery = false,
    this.enforceIp = true,
    this.cookieDomain,
    this.cookiePath = '/',
    this.cookieSameSite = SameSite.lax,
    this.secureCookies = true,
    this.reviveTokenEndpoint = '/auth/token',
    this.reviveGracePeriod = Duration.zero,
  }) : super() {
    _hs256 = Hmac(sha256, (jwtKey ?? _randomString()).codeUnits);
    _jwtLifeSpan = (jwtLifeSpan ?? defaultJwtLifeSpan).toInt();
    if (_jwtLifeSpan < 0 && jwtKey != null) {
      _log.warning(
        'JWTs signed with a fixed jwtKey never expire, as jwtLifeSpan is '
        '-1: a JWT stolen once is valid for ever.',
      );
    }
  }

  /// Configures an Angel server to decode and validate JSON Web tokens on demand,
  /// whenever an instance of [User] is injected.
  Future<void> configureServer(Angel app) async {
    var appContainer = app.container;

    appContainer.registerSingleton(this);
    if (runtimeType != AngelAuth) {
      appContainer.registerSingleton(this, as: AngelAuth);
    }

    if (!appContainer.has<_AuthResult<User>>()) {
      appContainer.registerLazySingleton<Future<_AuthResult<User>>>((
        container,
      ) async {
        var req = container.make<RequestContext>();
        var res = container.make<ResponseContext>();

        var result = await _decodeJwt(req, res);
        if (result != null) {
          return result;
        } else {
          _log.warning('JWT is null');
          throw AngelHttpException.forbidden();
        }
      });

      appContainer.registerLazySingleton<Future<User>>((container) async {
        var result = await container.makeAsync<_AuthResult<User>>();
        return result.user;
      });

      appContainer.registerLazySingleton<Future<AuthToken>>((container) async {
        var result = await container.makeAsync<_AuthResult<User>>();
        return result.token;
      });
    }

    app.post(reviveTokenEndpoint, _reviveJwt);

    app.shutdownHooks.add((_) async {
      await _onLogin.close();
      await _onLogout.close();
    });
  }

  /// Makes [user] and [token] those of the request, and, if [setCookie],
  /// sets the `token` cookie to [token].
  void _apply(
    RequestContext req,
    ResponseContext res,
    AuthToken token,
    User user, {
    bool setCookie = true,
  }) {
    if (req.container == null) {
      _log.severe('RequestContext.container is null');
      throw StateError(
        'RequestContext.container is not set. All authentication will fail.',
      );
    }

    var reqContainer = req.container!;
    if (!reqContainer.has<User>()) {
      reqContainer.registerSingleton<User>(user);
    }

    if (!reqContainer.has<AuthToken>()) {
      reqContainer.registerSingleton<AuthToken>(token);
    }

    if (allowCookie && setCookie) {
      _addProtectedCookie(res, 'token', token.serialize(_hs256));
    }
  }

  /// Throws a 403 if [token] may not be used by [req]: of another IP address
  /// when [enforceIp].
  void _checkIp(AuthToken token, RequestContext req) {
    if (enforceIp && req.ip != token.ipAddress) {
      _log.warning('JWT cannot be accessed from this IP address');
      throw AngelHttpException.forbidden(
        message: 'JWT cannot be accessed from this IP address.',
      );
    }
  }

  /// The user of [userId], or a 403 if there is none (any more).
  Future<User> _userOf(String userId) async {
    var user = await deserializer(userId);
    if (user == null) {
      _log.warning('The user of a JWT does not exist');
      throw AngelHttpException.forbidden(
        message: 'The user of the JWT does not exist.',
      );
    }
    return user;
  }

  Future<_AuthResult<User>?> _decodeJwt(
    RequestContext req,
    ResponseContext res,
  ) async {
    var jwt = getJwt(req);

    if (jwt != null) {
      var token = AuthToken.validate(jwt, _hs256);
      _checkIp(token, req);

      if (token.isExpired()) {
        _log.warning('Expired JWT');
        throw AngelHttpException.forbidden(message: 'Expired JWT.');
      }

      var user = await _userOf(token.userId);
      // The JWT came with the request: one of an `Authorization` header is
      // not put in a cookie, and one of a cookie is already there.
      _apply(req, res, token, user, setCookie: false);
      return _AuthResult(user, token);
    }

    return null;
  }

  /// Retrieves a JWT from a request, if any was sent at all: of a `Bearer`
  /// `Authorization` header, or else of the `token` cookie, if
  /// [allowCookie], or of the `token` query parameter, if
  /// [allowTokenInQuery].
  String? getJwt(RequestContext req) {
    final authHeader = req.headers?.value('Authorization');
    if (authHeader != null) {
      // Other schemes (e.g. Basic) are for the strategies.
      return _rgxBearer.firstMatch(authHeader)?.group(1)?.trim();
    }

    if (allowCookie) {
      for (var cookie in req.cookies) {
        if (cookie.name == 'token' && cookie.value.isNotEmpty) {
          return cookie.value;
        }
      }
    }

    if (allowTokenInQuery) {
      var token = req.uri?.queryParameters['token'];
      if (token != null && token.isNotEmpty) return token;
    }

    return null;
  }

  void _addProtectedCookie(ResponseContext res, String name, String value) {
    if (!res.cookies.any((c) => c.name == name)) {
      res.cookies.add(protectCookie(Cookie(name, value)));
    }
  }

  /// Applies security protections to a [cookie].
  Cookie protectCookie(Cookie cookie) {
    if (secureCookies != false) {
      cookie.httpOnly = true;
      cookie.secure = true;
    }

    var lifeSpan = _jwtLifeSpan;
    if (lifeSpan > 0) {
      cookie.maxAge ??= lifeSpan ~/ 1000;
      cookie.expires ??= DateTime.now().add(Duration(milliseconds: lifeSpan));
    }

    cookie.domain ??= cookieDomain;
    cookie.path ??= cookiePath;
    cookie.sameSite ??= cookieSameSite;
    return cookie;
  }

  /// Exchanges a JWT that is still valid, or expired by no more than
  /// [reviveGracePeriod], for a new one, of the user it is of, who must still
  /// exist.
  Future<Map<String, dynamic>> _reviveJwt(
    RequestContext req,
    ResponseContext res,
  ) async {
    var jwt = getJwt(req);

    if (jwt == null) {
      try {
        await req.parseBody();
        jwt = req.bodyAsMap['token']?.toString();
      } on FormatException {
        throw AngelHttpException.badRequest(message: 'Malformed body');
      }
    }

    if (jwt == null || jwt.isEmpty) {
      _log.warning('No JWT provided');
      throw AngelHttpException.forbidden(message: 'No JWT provided');
    }

    var token = AuthToken.validate(jwt, _hs256);
    _checkIp(token, req);

    if (token.isExpired(DateTime.now().subtract(reviveGracePeriod))) {
      _log.warning('Expired JWT');
      throw AngelHttpException.forbidden(message: 'Expired JWT.');
    }

    var user = await _userOf(token.userId);
    var revived = AuthToken(
      userId: token.userId,
      lifeSpan: _jwtLifeSpan,
      ipAddress: token.ipAddress,
      payload: token.payload,
    );
    var serialized = revived.serialize(_hs256);

    if (allowCookie) {
      res.cookies.removeWhere((cookie) => cookie.name == 'token');
      _addProtectedCookie(res, 'token', serialized);
    }

    return {'data': user, 'token': serialized};
  }

  /// Attempts to authenticate a user using one or more strategies.
  ///
  /// [type] is a strategy name to try, or a `List` of such.
  ///
  /// If a strategy returns `null` or `false`, either the next one is tried,
  /// or a `401 Not Authenticated` is thrown, if it is the last one.
  ///
  /// Any other result is considered an authenticated user, and terminates the loop.
  RequestHandler authenticate(Object type, [AngelAuthOptions<User>? opt]) {
    return (RequestContext req, ResponseContext res) async {
      var authOption = opt ?? AngelAuthOptions<User>();

      var names = <String>[];

      var arr = type is Iterable
          ? type.map((x) => x.toString()).toList()
          : [type.toString()];

      for (var t in arr) {
        var n = t
            .split(',')
            .map((s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
        names.addAll(n);
      }

      for (var i = 0; i < names.length; i++) {
        var name = names[i];

        var strategy = strategies[name];
        if (strategy == null) {
          _log.severe('No strategy "$name" found.');
          throw ArgumentError('No strategy "$name" found.');
        }

        var reqContainer = req.container;
        if (reqContainer == null) {
          _log.warning('RequestContext.container is null');
        }

        var hasExisting = reqContainer?.has<User>() ?? false;
        var result = hasExisting
            ? reqContainer?.make<User>()
            : await strategy.authenticate(req, res, authOption);

        if (result == true) {
          return result;
        } else if (result != null && result != false) {
          var userId = await serializer(result);

          // Create JWT
          var token = AuthToken(
            userId: userId,
            lifeSpan: _jwtLifeSpan,
            ipAddress: req.ip,
          );
          var jwt = token.serialize(_hs256);

          if (authOption.tokenCallback != null) {
            var hasUser = reqContainer?.has<User>() ?? false;
            if (!hasUser) {
              reqContainer?.registerSingleton<User>(result);
            }

            var r = await authOption.tokenCallback!(req, res, token, result);
            if (r != null) return r;
            jwt = token.serialize(_hs256);
          }

          _apply(req, res, token, result, setCookie: false);

          if (allowCookie) {
            _addProtectedCookie(res, 'token', jwt);
          }

          // Options is not null
          if (authOption.callback != null) {
            return await authOption.callback!(req, res, jwt);
          }

          if (authOption.successRedirect?.isNotEmpty == true) {
            await res.redirect(authOption.successRedirect);
            return false;
          } else if (authOption.canRespondWithJson &&
              req.accepts('application/json')) {
            var user = hasExisting
                ? result
                : await deserializer(await serializer(result));
            _onLogin.add(user);
            return {'data': user, 'token': jwt};
          }

          return true;
        } else {
          if (i < names.length - 1) continue;
          // A strategy that answered the request itself, as with an error
          // page, or a redirect.
          if (!res.isOpen ||
              res.statusCode == 301 ||
              res.statusCode == 302 ||
              res.headers.containsKey('location')) {
            return false;
          } else if (authOption.failureRedirect != null) {
            await res.redirect(authOption.failureRedirect);
            return false;
          } else {
            _log.warning('Not authenticated');
            throw AngelHttpException.notAuthenticated();
          }
        }
      }
    };
  }

  /// Log a user in on-demand.
  Future login(AuthToken token, RequestContext req, ResponseContext res) async {
    var user = await deserializer(token.userId);
    _apply(req, res, token, user);
    _onLogin.add(user);
  }

  /// Log a user in on-demand.
  Future loginById(
    String userId,
    RequestContext req,
    ResponseContext res,
  ) async {
    var user = await deserializer(userId);
    var token = AuthToken(
      userId: userId,
      lifeSpan: _jwtLifeSpan,
      ipAddress: req.ip,
    );
    _apply(req, res, token, user);
    _onLogin.add(user);
  }

  /// Log an authenticated user out: the `token` cookie, if [allowCookie], is
  /// expired, so the browser drops it.
  ///
  /// A JWT is not revoked: one that was copied stays valid until it expires.
  RequestHandler logout([AngelAuthOptions<User>? options]) {
    return (RequestContext req, ResponseContext res) async {
      if (req.container?.has<User>() == true) {
        var user = req.container?.make<User>();
        if (user != null) {
          _onLogout.add(user);
        }
      }

      if (allowCookie == true) {
        res.cookies.removeWhere((cookie) => cookie.name == 'token');
        res.cookies.add(
          protectCookie(
            Cookie('token', '')
              ..maxAge = 0
              ..expires = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
      }

      if (options != null &&
          options.successRedirect != null &&
          options.successRedirect!.isNotEmpty) {
        await res.redirect(options.successRedirect);
      }

      return true;
    };
  }
}

class _AuthResult<User> {
  final User user;
  final AuthToken token;

  _AuthResult(this.user, this.token);
}
