import 'dart:io';

import '../core/core.dart' show ResponseContext;

/// The text of a header value, as [HttpHeaders] stores it: a [DateTime] in
/// HTTP-date form, any other value as [Object.toString].
String headerText(Object value) =>
    value is DateTime ? HttpDate.format(value) : '$value';

/// The values of a header given as [value]: each of a list, or [value]
/// itself. A `null` is no value.
Iterable<Object> headerValuesOf(Object? value) => [
  for (var v in value is Iterable ? value : [value])
    if (v != null) v as Object,
];

/// The values of [stored] that removing [value] removes: those equal to its
/// text, or, if there are none, those equal to it ignoring case, such as
/// `SAMEORIGIN` for `sameorigin`. So a value that differs in case only goes
/// when nothing matches exactly, which keeps case-sensitive values, such as
/// tokens, apart.
List<String> headerMatches(List<String> stored, Object value) {
  var text = headerText(value);
  var exact = [
    for (var v in stored)
      if (v == text) v,
  ];
  if (exact.isNotEmpty) return exact;
  var lower = text.toLowerCase();
  return [
    for (var v in stored)
      if (v.toLowerCase() == lower) v,
  ];
}

/// The values of [stored] that removing [value] removes, each once: all of
/// them for a `null` [value], else, for each of [headerValuesOf], its
/// [headerMatches] among those left.
List<String> valuesRemovedBy(List<String> stored, Object? value) {
  if (value == null) return [...stored];
  var left = [...stored];
  var removed = <String>[];
  for (var v in headerValuesOf(value)) {
    for (var match in headerMatches(left, v)) {
      left.remove(match);
      removed.add(match);
    }
  }
  return removed;
}

/// Throws an [ArgumentError] unless `dart:io` takes [value] for the header
/// [name], as [HttpHeaders.add] checks the type of a few: `connection`,
/// `content-type` and `host` take a string, `content-length` a non-negative
/// int or its digits, and `date`, `expires` and `if-modified-since` a
/// [DateTime] or a string.
void checkHttp1Value(String name, Object value) {
  bool ok;
  switch (name.toLowerCase()) {
    case HttpHeaders.connectionHeader:
    case HttpHeaders.contentTypeHeader:
    case HttpHeaders.hostHeader:
      ok = value is String;
    case HttpHeaders.contentLengthHeader:
      ok =
          (value is int && value >= 0) ||
          (value is String && RegExp(r'^\d{1,15}$').hasMatch(value));
    case HttpHeaders.dateHeader:
    case HttpHeaders.expiresHeader:
    case HttpHeaders.ifModifiedSinceHeader:
      ok = value is DateTime || value is String;
    default:
      ok = true;
  }
  if (!ok) {
    throw ArgumentError.value(value, name, 'Not a value of this header');
  }
}

/// Throws an [ArgumentError] unless [name] can be a header name.
void checkHeaderName(String name) {
  if (!ResponseContext.isValidHeaderName(name)) {
    throw ArgumentError.value(name, 'name', 'Not a header name');
  }
}

/// Throws an [ArgumentError] unless each of [headers] can be sent, on
/// HTTP/2 and by the rules of `dart:io` for HTTP/1, so that a call that adds
/// them can add all or none.
void checkHeaders(Map<String, Object?> headers) {
  headers.forEach((name, value) {
    checkHeaderName(name);
    for (var v in headerValuesOf(value)) {
      checkHttp1Value(name, v);
      var text = headerText(v);
      if (!ResponseContext.isValidHeaderValue(text)) {
        throw ArgumentError.value(text, name, 'Cannot be sent as a header');
      }
      if (name.toLowerCase() == HttpHeaders.setCookieHeader) {
        try {
          Cookie.fromSetCookieValue(text);
        } catch (e) {
          // An HttpException or a FormatException, as dart:io parses it.
          throw ArgumentError.value(text, name, 'Not a cookie: $e');
        }
      }
    }
  });
}

/// A copy of [headers], with a copy of each list, so that a list the caller
/// changes afterwards does not change headers that were checked.
Map<String, Object?> copyHeaders(Map<String, Object?> headers) => {
  for (var MapEntry(:key, :value) in headers.entries)
    key: value is Iterable ? List<Object?>.of(value) : value,
};

/// Adds and removes the values of headers given as maps, as the default
/// headers of `AngelHttp` and `AngelHttp2` take them.
extension HttpHeadersValues on HttpHeaders {
  /// Adds each value of each header: each value of a list, skipping a
  /// `null`.
  void addValues(Map<String, Object?> headers) {
    headers.forEach((name, value) {
      for (var v in headerValuesOf(value)) {
        add(name, v);
      }
    });
  }

  /// Removes the given values of each header: each value of a list, with
  /// [headerMatches]. A `null` value removes the header, whatever its values.
  void removeValues(Map<String, Object?> headers) {
    headers.forEach((name, value) {
      if (value == null) {
        removeAll(name);
        return;
      }
      for (var match in valuesRemovedBy([...?this[name]], value)) {
        remove(name, match);
      }
    });
  }
}
