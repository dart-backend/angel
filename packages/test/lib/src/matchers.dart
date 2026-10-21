import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:angel3_http_exception/angel3_http_exception.dart';
import 'package:angel3_validate/angel3_validate.dart';

/// Expects a response to be a JSON representation of an `AngelHttpException`.
///
/// You can optionally check for a matching [message], [statusCode] and [errors].
Matcher isAngelHttpException({
  String? message,
  int? statusCode,
  Iterable<String> errors = const [],
}) => _IsAngelHttpException(
  message: message,
  statusCode: statusCode,
  errors: errors,
);

/// Expects a given response, when parsed as JSON,
/// to equal a desired value.
Matcher isJson(dynamic value) => _IsJson(value);

/// Expects a response to have the given content type, whether a `String` or [ContentType].
Matcher hasContentType(dynamic contentType) => _HasContentType(contentType);

/// Expects a response to have the given body.
///
/// If `true` is passed as the value (default), then this matcher will simply assert
/// that the response has a non-empty body.
///
/// If value is a `List<int>`, then it will be matched against `res.bodyBytes`.
/// Otherwise, the string value will be matched against `res.body`.
Matcher hasBody([dynamic value]) => _HasBody(value ?? true);

/// Expects a response to have a header named [key] which contains [value]. [value] can be a `String`, or a List of `String`s.
///
/// If `value` is true (default), then this matcher will simply assert that the header is present.
Matcher hasHeader(String key, [value]) => _HasHeader(key, value ?? true);

/// Expects a response to have the given status code.
Matcher hasStatus(int status) => _HasStatus(status);

/// Expects a response to have a JSON body that is a `Map` and satisfies the given [validator] schema.
Matcher hasValidBody(Validator validator) => _HasValidBody(validator);

String notHttpResponse = "expected http.Response but got none\n";

/// Stands for a body that is not JSON, which no matcher matches.
const _notJson = Object();

/// The JSON of [body], or [_notJson].
Object? _decode(String body) {
  try {
    return json.decode(body);
  } on FormatException {
    return _notJson;
  }
}

/// Describes the body of [item], for a mismatch.
Description _describeBody(Object? item, Description description) {
  if (item is! http.Response) return description.add(notHttpResponse);

  var body = item.body;
  if (body.length > 200) body = '${body.substring(0, 200)}...';
  return identical(_decode(item.body), _notJson)
      ? description.add('has a body that is not JSON: $body')
      : description.add('has the body $body');
}

class _IsJson extends Matcher {
  dynamic value;

  _IsJson(this.value);

  @override
  Description describe(Description description) {
    return description.add('equals the desired JSON response: $value');
  }

  @override
  bool matches(item, Map matchState) =>
      item is http.Response &&
      equals(value).matches(_decode(item.body), matchState);

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) => _describeBody(item, mismatchDescription);
}

class _HasBody extends Matcher {
  final dynamic body;

  _HasBody(this.body);

  @override
  Description describe(Description description) =>
      description.add('has body $body');

  @override
  bool matches(item, Map matchState) {
    if (item is http.Response) {
      if (body == true) return isNotEmpty.matches(item.bodyBytes, matchState);
      if (body is List<int>) {
        return equals(body).matches(item.bodyBytes, matchState);
      } else {
        return equals(body.toString()).matches(item.body, matchState);
      }
    } else {
      return false;
    }
  }
}

class _HasContentType extends Matcher {
  dynamic contentType;

  _HasContentType(this.contentType);

  @override
  Description describe(Description description) {
    var str = contentType is ContentType
        ? ((contentType as ContentType).value)
        : contentType.toString();
    return description.add('has content type $str');
  }

  @override
  bool matches(item, Map matchState) {
    if (item is http.Response) {
      //if (!item.headers.containsKey('content-type')) return false;

      var headerContentType = item.headers['content-type'];
      if (headerContentType == null) return false;

      if (contentType is ContentType) {
        var compare = ContentType.parse(headerContentType);
        return equals(contentType.mimeType)
            .matches(compare.mimeType, matchState);
      } else {
        return equals(contentType.toString())
            .matches(headerContentType, matchState);
      }
    }

    return false;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is http.Response) {
      var headerContentType = item.headers['content-type'] ?? 'none';
      mismatchDescription.add(
        "expected '$contentType' but got '$headerContentType'\n",
      );
    } else {
      mismatchDescription.add(notHttpResponse);
    }
    return mismatchDescription;
  }
}

class _HasHeader extends Matcher {
  final String key;
  final dynamic value;

  _HasHeader(this.key, this.value);

  @override
  Description describe(Description description) {
    if (value == true) {
      return description.add('contains header $key');
    } else {
      return description.add('contains header $key with value(s) $value');
    }
  }

  @override
  bool matches(item, Map matchState) {
    if (item is http.Response) {
      if (value == true) {
        return contains(key.toLowerCase())
            .matches(item.headers.keys, matchState);
      } else {
        var headerKey = item.headers[key.toLowerCase()];
        if (headerKey == null) return false;
        var v = value is Iterable ? (value as Iterable) : [value];
        return v.map((x) => x.toString()).every(headerKey.split(',').contains);
      }
    } else {
      return false;
    }
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is http.Response) {
      mismatchDescription.add("expected '$key' but got none\n");
    } else {
      mismatchDescription.add(notHttpResponse);
    }
    return mismatchDescription;
  }
}

class _HasStatus extends Matcher {
  int status;

  _HasStatus(this.status);

  @override
  Description describe(Description description) {
    return description.add('has status code $status');
  }

  @override
  bool matches(item, Map matchState) =>
      item is http.Response &&
      equals(status).matches(item.statusCode, matchState);

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is http.Response) {
      mismatchDescription.add('expected $status but got ${item.statusCode}\n');
    } else {
      mismatchDescription.add(notHttpResponse);
    }
    return mismatchDescription;
  }
}

class _HasValidBody extends Matcher {
  final Validator validator;

  _HasValidBody(this.validator);

  @override
  Description describe(Description description) =>
      description.add('matches validation schema ${validator.rules}');

  @override
  bool matches(item, Map matchState) {
    if (item is http.Response) {
      final jsons = _decode(item.body);
      if (jsons is Map) {
        try {
          return validator.matches(jsons, matchState);
        } on ValidationException catch (e) {
          // In [matchState], so a matcher used twice keeps the errors of each.
          matchState['errors'] = e.errors;
        } catch (e) {
          matchState['errors'] = ['$e'];
        }
      }
    }
    return false;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    var errors = matchState['errors'];
    if (item is! http.Response || errors is! List) {
      return _describeBody(item, mismatchDescription);
    }

    for (var err in errors) {
      mismatchDescription.add('$err\n');
    }
    return mismatchDescription;
  }
}

class _IsAngelHttpException extends Matcher {
  String? message;
  int? statusCode;
  final List<String> errors = [];

  _IsAngelHttpException({
    this.message,
    this.statusCode,
    Iterable<String> errors = const [],
  }) {
    this.errors.addAll(errors);
  }

  @override
  Description describe(Description description) {
    if (message?.isNotEmpty != true && statusCode == null && errors.isEmpty) {
      return description.add('is an Angel HTTP Exception');
    } else {
      var buf = StringBuffer('is an Angel HTTP Exception with');

      if (statusCode != null) buf.write(' status code $statusCode');

      if (message?.isNotEmpty == true) {
        if (statusCode != null && errors.isNotEmpty) {
          buf.write(',');
        } else if (statusCode != null && errors.isEmpty) {
          buf.write(' and');
        }
        buf.write(' message "$message"');
      }

      if (errors.isNotEmpty) {
        if (statusCode != null || message?.isNotEmpty == true) {
          buf.write(' and errors $errors');
        } else {
          buf.write(' errors $errors');
        }
      }

      return description.add(buf.toString());
    }
  }

  @override
  bool matches(item, Map matchState) {
    if (item is http.Response) {
      final jsons = _decode(item.body);

      // AngelHttpException.toJson writes is_error; isError is the old key.
      if (jsons is Map &&
          (jsons['is_error'] == true || jsons['isError'] == true)) {
        var exc = AngelHttpException.fromMap(
          jsons,
          fallbackStatusCode: item.statusCode,
        );
        matchState['exception'] = exc;

        if (message?.isNotEmpty != true &&
            statusCode == null &&
            errors.isEmpty) {
          return true;
        } else {
          if (statusCode != null) {
            if (!equals(statusCode).matches(exc.statusCode, matchState)) {
              return false;
            }
          }

          if (message?.isNotEmpty == true) {
            if (!equals(message).matches(exc.message, matchState)) {
              return false;
            }
          }

          if (errors.isNotEmpty) {
            if (!errors.every(
              (err) => contains(err).matches(exc.errors, matchState),
            )) {
              return false;
            }
          }

          return true;
        }
      } else {
        return false;
      }
    } else {
      return false;
    }
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    var exc = matchState['exception'];
    if (exc is! AngelHttpException) {
      return _describeBody(item, mismatchDescription);
    }

    mismatchDescription.add(
      'is an Angel HTTP Exception with status code ${exc.statusCode} and '
      'message "${exc.message}"',
    );
    if (exc.errors.isNotEmpty) {
      mismatchDescription.add(' and errors ${exc.errors}');
    }
    return mismatchDescription;
  }
}
