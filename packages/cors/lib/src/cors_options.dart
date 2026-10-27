import 'dart:async';

/// CORS configuration options.
///
/// The default configuration is the equivalent of:
///
///```json
///{
///  "origin": "*",
///  "methods": "GET,HEAD,PUT,PATCH,POST,DELETE",
///  "preflightContinue": false
///}
/// ```
class CorsOptions {
  /// Configures the **Access-Control-Allow-Headers** CORS header. Expects a comma-delimited string (ex: 'Content-Type,Authorization') or an array (ex: `['Content-Type', 'Authorization']`). If not specified, defaults to reflecting the headers specified in the request's **Access-Control-Request-Headers** header.
  final List<String> allowedHeaders = [];

  /// Configures the **Access-Control-Allow-Credentials** CORS header. Set to `true` to pass the header, otherwise it is omitted.
  ///
  /// Browsers refuse credentials with the default [origin] of `'*'`: give the
  /// origins to allow instead. Allowing every origin (`origin: true`) with
  /// credentials lets any site act as the user.
  final bool credentials;

  /// Configures the **Access-Control-Expose-Headers** CORS header. Expects a comma-delimited string (ex: 'Content-Range,X-Content-Range') or an array (ex: `['Content-Range', 'X-Content-Range']`). If not specified, no custom headers are exposed.
  final List<String> exposedHeaders = [];

  /// Configures the **Access-Control-Max-Age** CORS header. Set to an integer to pass the header, otherwise it is omitted.
  ///
  /// Default: `null`
  final int? maxAge;

  /// The status code to be sent on preflight requests (`OPTIONS` with an
  /// `Access-Control-Request-Method` header), if [preflightContinue] is `false`.
  final int successStatus;

  /// Configures the **Access-Control-Allow-Methods** CORS header. Expects a comma-delimited string (ex: 'GET,PUT,POST') or an array (ex: `['GET', 'PUT', 'POST']`).
  ///
  /// Default: `['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE˝']`
  final List<String> methods = [];

  /// Configures the **Access-Control-Allow-Origin** CORS header.
  /// Possible values:
  /// - `Boolean` - set `origin` to `true` to reflect the [request origin](http://tools.ietf.org/html/draft-abarth-origin-09), as defined by `req.header('Origin')`, or set it to `false` to disable CORS.
  /// - `String` - set `origin` to a specific origin. For example if you set it to `"http://example.com"` only requests from "http://example.com" will be allowed.
  ///  - `RegExp` - set `origin` to a regular expression pattern which will be used to test the request origin. If it's a match, the request origin will be reflected. For example the pattern `/example\.com$/` will reflect any request that is coming from an origin ending with "example.com".
  /// - `Array` - set `origin` to an array of valid origins. Each origin can be a `String` or a `RegExp`. For example `["http://example1.com", /\.example2\.com$/]` will accept any request from "http://example1.com" or from a subdomain of "example2.com".
  /// - `FutureOr<bool> Function(String)` - set `origin` to a function implementing some custom logic. The function takes the request origin as the first parameter and returns a [bool], or a [Future] of one.
  ///
  /// A request whose origin is not allowed, or that has none, gets no
  /// **Access-Control-Allow-Origin** header. A value of any other type is an
  /// [ArgumentError].
  ///
  /// Default: `'*'`
  final dynamic origin;

  /// If `false`, then the [cors] handler will terminate the response to a
  /// preflight request after performing its logic. If `true`, it leaves the
  /// response open, for the handlers after it.
  ///
  /// Default: `false`
  final bool preflightContinue;

  CorsOptions({
    Iterable<String> allowedHeaders = const [],
    this.credentials = false,
    this.maxAge,
    Iterable<String> methods = const [
      'GET',
      'HEAD',
      'PUT',
      'PATCH',
      'POST',
      'DELETE',
    ],
    this.origin = '*',
    this.successStatus = 204,
    this.preflightContinue = false,
    Iterable<String> exposedHeaders = const [],
  }) {
    this.allowedHeaders.addAll(allowedHeaders);

    this.methods.addAll(methods);

    this.exposedHeaders.addAll(exposedHeaders);

    if (!_isValidOrigin(origin, top: true)) {
      throw ArgumentError.value(
        origin,
        'origin',
        'must be a bool, a String, a RegExp, a FutureOr<bool> '
            'Function(String), or a list of Strings, RegExps and functions',
      );
    }
  }

  static bool _isValidOrigin(Object? origin, {bool top = false}) {
    if (origin is String ||
        origin is RegExp ||
        origin is FutureOr<bool> Function(String)) {
      return true;
    } else if (top && origin is bool) {
      return true;
    } else if (top && origin is Iterable) {
      return origin.every(_isValidOrigin);
    }
    return false;
  }
}
