import 'dart:async';
import 'dart:io';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:shelf/shelf.dart' as shelf;

class ShelfRequestContext extends RequestContext {
  final Angel angelApp;

  @override
  final Container container;
  @override
  final shelf.Request rawRequest;
  @override
  final String path;

  List<Cookie>? _cookies;

  @override
  final MockHttpHeaders headers = MockHttpHeaders();

  /// Throws [AngelHttpException.badRequest] when [request]'s framing headers
  /// are invalid; see [checkRequestFraming].
  ShelfRequestContext(
    this.angelApp,
    this.container,
    shelf.Request request,
    this.path,
  ) : rawRequest = checkRequestFraming(request) {
    rawRequest.headers.forEach(headers.add);
  }

  @override
  Stream<List<int>> get body => rawRequest.read();

  @override
  List<Cookie> get cookies {
    if (_cookies == null) {
      // Parse cookies
      _cookies = [];
      var value = headers.value('cookie');
      if (value != null) {
        var cookieStrings = value.split(';').map((s) => s.trim());

        for (var cookieString in cookieStrings) {
          try {
            _cookies!.add(Cookie.fromSetCookieValue(cookieString));
          } catch (_) {
            // Ignore malformed cookies, and just don't add them to the container.
          }
        }
      }
    }
    return _cookies!;
  }

  @override
  String get hostname => rawRequest.headers['host']!;

  @override
  String get method {
    if (!angelApp.allowMethodOverrides) {
      return originalMethod;
    } else {
      return headers.value('x-http-method-override')?.toUpperCase() ??
          originalMethod;
    }
  }

  @override
  String get originalMethod => rawRequest.method;

  @override
  // TODO: implement remoteAddress
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;

  @override
  // TODO: implement session
  HttpSession? get session => null;

  @override
  Uri get uri => rawRequest.url;
}

/// Checks [request]'s message framing headers, as RFC 9112 §6 asks of a
/// server, and returns it with repeated identical `Content-Length` values
/// collapsed into one.
///
/// Throws [AngelHttpException.badRequest] when `Content-Length` is malformed
/// or has differing values, or comes with `Transfer-Encoding`. Two hops that
/// read such a request's length differently can be used to smuggle requests,
/// so it is rejected rather than guessed at.
shelf.Request checkRequestFraming(shelf.Request request) {
  var contentLength = request.headers[HttpHeaders.contentLengthHeader];
  if (contentLength == null) return request;

  if (request.headers.containsKey(HttpHeaders.transferEncodingHeader)) {
    throw AngelHttpException.badRequest(
      message: 'Content-Length and Transfer-Encoding cannot both be sent.',
    );
  }

  // shelf joins repeated headers with ','.
  var lengths = contentLength.split(',').map(_parseContentLength).toSet();
  if (lengths.length != 1 || lengths.first == null) {
    throw AngelHttpException.badRequest(
      message: 'Invalid Content-Length: $contentLength',
    );
  }

  var length = '${lengths.first}';
  if (length == contentLength) return request;
  return request.change(headers: {HttpHeaders.contentLengthHeader: length});
}

final RegExp _digits = RegExp(r'^[0-9]+$');

// As in MockHttpHeaders: digits only, and fewer than 16 significant digits.
int? _parseContentLength(String value) {
  value = value.trim();
  if (!_digits.hasMatch(value)) return null;
  var significant = value.replaceFirst(RegExp(r'^0+(?=.)'), '');
  if (significant.length >= 16) return null;
  return int.parse(significant);
}
