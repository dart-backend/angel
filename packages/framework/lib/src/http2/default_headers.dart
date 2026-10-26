import 'dart:io';

import 'package:http2/transport.dart';

import '../http/headers.dart';

/// The default headers of HTTP/2 responses, which have no server to keep
/// them, as `HttpServer.defaultResponseHeaders` keeps those of HTTP/1: added
/// and removed by the same rules, and sent with a response's headers. A
/// header that the response sets replaces one of the same name.
///
/// [HttpHeaders] cannot be made on its own, so this mirrors the rules of
/// `dart:io` that HTTP/2 responses need, which must be kept in step with
/// it: names merged ignoring case; one value kept for [_singleValued]
/// headers, which a new one replaces; several values of any other header
/// sent as one, joined with `, `, except `set-cookie`, one header each; and
/// the removal rules of [valuesRemovedBy].
class DefaultResponseHeaders {
  /// The values by lowercase name, merged as [HttpHeaders.add] merges names
  /// that differ in case. A `set-cookie` keeps its text as given, as HTTP/1
  /// sends it.
  final Map<String, List<String>> _values = {};

  /// The headers that HTTP/2 responses do not get from the defaults, which
  /// the HTTP/1 ones do: those HTTP/2 forbids (RFC 9113, section 8.2.2), and
  /// `content-length`, which only a response knows, as it may compress its
  /// body.
  static const _notSent = {
    'connection',
    'keep-alive',
    'proxy-connection',
    'transfer-encoding',
    'upgrade',
    HttpHeaders.contentLengthHeader,
  };

  /// The headers that `dart:io` keeps one value of, which a new one
  /// replaces.
  static const _singleValued = {
    HttpHeaders.contentLengthHeader,
    HttpHeaders.contentTypeHeader,
    HttpHeaders.dateHeader,
    HttpHeaders.expiresHeader,
    HttpHeaders.hostHeader,
    HttpHeaders.ifModifiedSinceHeader,
  };

  /// Adds [headers], which [checkHeaders] must have accepted.
  void add(Map<String, Object?> headers) {
    headers.forEach((name, value) {
      var values = [for (var v in headerValuesOf(value)) headerText(v)];
      if (values.isEmpty) return;
      var key = name.toLowerCase();
      if (_singleValued.contains(key)) {
        // The last, as dart:io replaces the value with each one it adds.
        _values[key] = [values.last];
      } else {
        _values.putIfAbsent(key, () => []).addAll(values);
      }
    });
  }

  /// Removes [headers], whose names [checkHeaderName] must have accepted, as
  /// [HttpHeadersValues.removeValues] removes them from [HttpHeaders].
  void remove(Map<String, Object?> headers) {
    headers.forEach((name, value) {
      var key = name.toLowerCase();
      var stored = _values[key];
      if (stored == null) return;
      for (var match in valuesRemovedBy(stored, value)) {
        stored.remove(match);
      }
      if (stored.isEmpty) _values.remove(key);
    });
  }

  /// The headers to send with a response whose own headers have [names]
  /// (in lowercase): the defaults it has none of, one header of the values
  /// of each, as an HTTP/2 response has, and the default cookies unless it
  /// has a `set-cookie`. They go before the response's own cookies, so that
  /// one of those comes last and wins, as with `dart:io`, which sends a
  /// response's cookies after its headers.
  List<Header> headersFor(Set<String> names) {
    var headers = <Header>[];
    _values.forEach((name, values) {
      if (names.contains(name) || _notSent.contains(name)) return;
      if (name == HttpHeaders.setCookieHeader) {
        for (var cookie in values) {
          headers.add(Header.ascii(name, cookie));
        }
      } else {
        headers.add(Header.ascii(name, values.join(', ')));
      }
    });
    return headers;
  }
}
