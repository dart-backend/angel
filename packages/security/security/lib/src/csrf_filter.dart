import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:angel3_framework/angel3_framework.dart';

import 'constant_time.dart';
import 'cookie_signer.dart';

/// The CSRF token of a request, which [CsrfFilter] registers in its
/// container, e.g. for a template to put in a form's [CsrfFilter.fieldName]
/// field.
class CsrfToken {
  final String value;

  CsrfToken(this.value);
}

/// Protects against cross-site request forgery (CSRF).
///
/// Requests that may change state (all but `GET`, `HEAD`, `OPTIONS` and
/// `TRACE`) must pass two checks, or are refused with a 403:
///
/// * They come from an allowed origin: `Sec-Fetch-Site` is `same-origin` (or
///   `none`, a request the user made), or else the `Origin` (or `Referer`) is
///   one of [allowedOrigins].
/// * They send the token back, in the [headerName] header or the [fieldName]
///   body field. The token is the value of the [cookieName] cookie, signed by
///   [signer] and bound to the session, so it cannot be forged or planted by
///   another site (a signed double-submit cookie).
///
/// The cookie is issued to a request without a valid one. It is readable by
/// scripts, so that a client can send its value in [headerName] (as axios and
/// Angular do); another site can make a browser send the cookie, but cannot
/// read it. A page can also take the token of a request from its [CsrfToken].
///
/// By default the token is bound to the session, which [sessionKey] reads,
/// creating one for each visitor. A form shown before its session expired is
/// then refused; the next page gets a new token.
///
/// ```dart
/// var csrf = CsrfFilter(signer, allowedOrigins: {'https://example.com'});
/// app.fallback(csrf.handleRequest);
/// ```
///
/// Requests authenticated otherwise than by cookies (e.g. with an
/// `Authorization` header, which a browser does not send by itself) can be
/// exempted with [skip].
class CsrfFilter {
  /// Signs the token cookie, with a key from the configuration.
  final CookieSigner signer;

  /// The origins (`https://example.com`, with no path) allowed to send
  /// requests that change state.
  final Set<String> allowedOrigins;

  /// The name of the cookie of the token.
  final String cookieName;

  /// The header in which a client sends the token back, e.g. from `fetch`.
  /// The default, `X-XSRF-TOKEN`, is the one axios and Angular send the
  /// value of the `XSRF-TOKEN` cookie in.
  final String headerName;

  /// The body field in which a form sends the token back.
  final String fieldName;

  /// Whether the cookie is `Secure`, as it should be but over plain HTTP
  /// (e.g. in development).
  final bool secureCookie;

  /// Requests that are not checked, e.g. those with a bearer token.
  final bool Function(RequestContext req)? skip;

  /// The value the token is bound to: by default, the id of the request's
  /// session (which reading creates). Return `null` to bind it to nothing.
  /// The cookie holds an HMAC of it, not the value itself, as scripts can
  /// read the cookie.
  final String? Function(RequestContext req) sessionKey;

  final Random _random = Random.secure();

  static const _safeMethods = {'GET', 'HEAD', 'OPTIONS', 'TRACE'};

  CsrfFilter(
    this.signer, {
    required this.allowedOrigins,
    this.cookieName = 'XSRF-TOKEN',
    this.headerName = 'x-xsrf-token',
    this.fieldName = '_csrf',
    this.secureCookie = true,
    this.skip,
    String? Function(RequestContext req)? sessionKey,
  }) : sessionKey = sessionKey ?? ((req) => req.session?.id);

  /// A request middleware that issues the token, and refuses requests that
  /// change state without passing the checks of [CsrfFilter].
  Future<bool> handleRequest(RequestContext req, ResponseContext res) async {
    if (skip?.call(req) == true) return true;

    // A filter that already ran on the request issued, or read, the token.
    var container = req.container;
    String token;
    if (container != null && container.has<CsrfToken>()) {
      token = container.make<CsrfToken>().value;
    } else {
      var key = _key(req);
      token = _readToken(req, key) ?? _issueToken(res, key);
      container?.registerSingleton(CsrfToken(token));
    }

    if (_safeMethods.contains(req.method.toUpperCase())) return true;

    if (!_originAllowed(req)) {
      throw AngelHttpException.forbidden(
        message: 'Cross-site request refused.',
      );
    }

    var sent = [
      for (var value in req.headers?[headerName] ?? const <String>[])
        if (value.isNotEmpty) value,
    ];
    // Several tokens are ambiguous, and refused; none, read from the body.
    if (sent.isEmpty) sent = [?await _fieldOf(req)];
    if (sent.length != 1 || !equalsInConstantTime(sent.single, token)) {
      throw AngelHttpException.forbidden(message: 'Invalid CSRF token.');
    }
    return true;
  }

  /// The token of the request: the value of its cookie, if it is signed by
  /// [signer] and bound to the request's session; otherwise `null`.
  CsrfToken? readCsrfToken(RequestContext req) {
    var token = _readToken(req, _key(req));
    return token == null ? null : CsrfToken(token);
  }

  String? _readToken(RequestContext req, String key) {
    for (var cookie in req.cookies) {
      if (cookie.name != cookieName) continue;
      var payload = signer.readPayload(cookie);
      var bang = payload?.lastIndexOf('!') ?? -1;
      if (bang < 0 || payload!.substring(0, bang) != key) continue;
      return cookie.value;
    }
    return null;
  }

  String _issueToken(ResponseContext res, String key) {
    var random = base64Url
        .encode(List.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    var cookie = signer.createSignedCookie(
      Cookie(cookieName, '$key!$random')
        ..path = '/'
        // Read by scripts, to send the token back; dart:io's default is true.
        ..httpOnly = false
        ..secure = secureCookie
        ..sameSite = SameSite.lax,
    );
    res.cookies.add(cookie);
    return cookie.value;
  }

  /// An HMAC of the session key, so that the cookie, which scripts can read,
  /// does not tell the session id.
  String _key(RequestContext req) => signer
      .computeCookieSignature('csrf-session:${sessionKey(req) ?? ''}')
      .replaceAll('=', '');

  bool _originAllowed(RequestContext req) {
    // A same-site or cross-site request may still be of an allowed origin
    // (e.g. https://example.com calling https://api.example.com).
    var site = _header(req, 'sec-fetch-site');
    if (site == 'same-origin' || site == 'none') return true;

    var origin = _header(req, 'origin');
    if (origin == null || origin == 'null') {
      origin = _originOf(_header(req, 'referer'));
    }
    return origin != null && allowedOrigins.contains(origin);
  }

  /// The value of the header [name], unless it is sent more than once, which
  /// `HttpHeaders.value` throws for.
  static String? _header(RequestContext req, String name) {
    var values = req.headers?[name];
    return values != null && values.length == 1 ? values.single : null;
  }

  static String? _originOf(String? url) {
    var uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    try {
      return uri.origin;
    } on StateError {
      return null;
    }
  }

  /// The token in the body, if the body is a form or JSON object. A body that
  /// cannot be parsed fails the request with its own error (e.g. a 413).
  Future<String?> _fieldOf(RequestContext req) async {
    await req.parseBody();
    var value = req.bodyAsMap[fieldName]?.toString();
    return value == null || value.isEmpty ? null : value;
  }
}
