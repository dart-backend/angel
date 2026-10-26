/// Angel CORS middleware.
library;

import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';

import 'src/cors_options.dart';
export 'src/cors_options.dart';

/// Whether [origin] is one of [allowedOrigin], which [CorsOptions] has
/// checked. Synchronous, unless a predicate returns a [Future].
FutureOr<bool> _isOriginAllowed(String origin, Object? allowedOrigin) {
  if (allowedOrigin is Iterable) {
    var pending = <Future<bool>>[];
    for (var x in allowedOrigin) {
      var allowed = _isOriginAllowed(origin, x);
      if (allowed is Future<bool>) {
        pending.add(allowed);
      } else if (allowed) {
        return true;
      }
    }
    if (pending.isEmpty) return false;
    return Future.wait(pending).then((all) => all.contains(true));
  } else if (allowedOrigin is String) {
    return origin == allowedOrigin;
  } else if (allowedOrigin is RegExp) {
    return allowedOrigin.hasMatch(origin);
  } else if (allowedOrigin is FutureOr<bool> Function(String)) {
    return allowedOrigin(origin);
  } else {
    return allowedOrigin == true;
  }
}

/// Adds `origin` to the `Vary` header, keeping what is already there.
void _varyOnOrigin(ResponseContext res) {
  var vary = res.headers['vary'];
  if (vary == null || vary.trim().isEmpty) {
    res.headers['vary'] = 'origin';
  } else if (!vary
      .split(',')
      .map((v) => v.trim().toLowerCase())
      .any((v) => v == 'origin' || v == '*')) {
    res.headers['vary'] = '$vary, origin';
  }
}

/// On-the-fly configures the [cors] handler. Use this when the context of the surrounding request
/// is necessary to decide how to handle an incoming request.
Future<bool> Function(RequestContext, ResponseContext) dynamicCors(
  FutureOr<CorsOptions> Function(RequestContext, ResponseContext) f,
) {
  return (req, res) async {
    var opts = await f(req, res);
    var handler = cors(opts);
    return await handler(req, res);
  };
}

/// Applies the given [CorsOptions].
///
/// A preflight request (an `OPTIONS` request with an
/// `Access-Control-Request-Method` header) is answered with
/// [CorsOptions.successStatus], unless [CorsOptions.preflightContinue] is
/// `true`; other requests continue. A preflight from an origin that is not
/// allowed is answered too, without CORS headers, so the browser refuses it.
Future<bool> Function(RequestContext, ResponseContext) cors([
  CorsOptions? options,
]) {
  final opts = options ?? CorsOptions();

  return (req, res) async {
    // CORS is disabled.
    if (opts.origin == false) return true;

    var origin = req.headers?.value('origin');
    // The method sent, which a method override does not change.
    var isPreflight =
        req.originalMethod == 'OPTIONS' &&
        req.headers?.value('access-control-request-method') != null;

    // access-control-allow-origin
    String? allowed;
    if (opts.origin == '*' || opts.origin is String) {
      allowed = opts.origin as String;
    } else {
      // The origin is reflected, so caches must keep each one's apart.
      _varyOnOrigin(res);
      if (origin != null && await _isOriginAllowed(origin, opts.origin)) {
        allowed = origin;
      }
    }

    // A refused origin, or a request without one, gets no CORS headers.
    if (allowed == null) {
      return isPreflight && !opts.preflightContinue
          ? _endPreflight(res, opts)
          : true;
    }
    res.headers['access-control-allow-origin'] = allowed;

    // access-control-allow-credentials
    if (opts.credentials) {
      res.headers['access-control-allow-credentials'] = 'true';
    }

    // access-control-expose-headers
    if (opts.exposedHeaders.isNotEmpty) {
      res.headers['access-control-expose-headers'] = opts.exposedHeaders.join(
        ',',
      );
    }

    if (!isPreflight) return true;

    // access-control-allow-headers: the configured ones, or else those the
    // preflight asks for.
    if (opts.allowedHeaders.isNotEmpty) {
      res.headers['access-control-allow-headers'] = opts.allowedHeaders.join(
        ',',
      );
    } else {
      var requested = req.headers?.value('access-control-request-headers');
      if (requested != null) {
        res.headers['access-control-allow-headers'] = requested;
      }
    }

    // access-control-allow-methods
    if (opts.methods.isNotEmpty) {
      res.headers['access-control-allow-methods'] = opts.methods.join(',');
    }

    // access-control-max-age
    if (opts.maxAge != null) {
      res.headers['access-control-max-age'] = opts.maxAge.toString();
    }

    // Left to the handlers after this one.
    if (opts.preflightContinue) return true;
    return _endPreflight(res, opts);
  };
}

/// Answers a preflight request with [CorsOptions.successStatus].
Future<bool> _endPreflight(ResponseContext res, CorsOptions opts) async {
  res.statusCode = opts.successStatus;
  res.contentLength = 0;
  await res.close();
  return false;
}
