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

  /// Why the request's framing headers were invalid (see
  /// [checkRequestFraming]), or `null` when they were valid.
  ///
  /// When this is set, `Content-Length` and `Transfer-Encoding` were removed
  /// from [rawRequest] and [headers] (shelf sets `Content-Length` again for a
  /// body of known length), and the request should be rejected with this
  /// error; `AngelShelf` does so before the request is handled. The
  /// constructor never throws for invalid framing.
  final AngelHttpException? framingError;

  List<Cookie>? _cookies;

  @override
  final MockHttpHeaders headers = MockHttpHeaders();

  ShelfRequestContext(
    Angel angelApp,
    Container container,
    shelf.Request request,
    String path,
  ) : this._(angelApp, container, path, _checkOrStrip(request));

  ShelfRequestContext._(
    this.angelApp,
    this.container,
    this.path,
    (shelf.Request, AngelHttpException?) framing,
  ) : rawRequest = framing.$1,
      framingError = framing.$2 {
    rawRequest.headers.forEach(headers.add);
  }

  static (shelf.Request, AngelHttpException?) _checkOrStrip(
    shelf.Request request,
  ) {
    try {
      return (checkRequestFraming(request), null);
    } on AngelHttpException catch (e) {
      var stripped = request.change(
        headers: {
          HttpHeaders.contentLengthHeader: null,
          HttpHeaders.transferEncodingHeader: null,
        },
      );
      return (stripped, e);
    }
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
/// or has differing values, when `Transfer-Encoding` does not end in a single
/// `chunked`, or when both are sent. Two hops that read such a request's
/// length differently can be used to smuggle requests, so it is rejected
/// rather than guessed at.
///
/// A request this returned is not checked again, so `AngelShelf` and
/// [ShelfRequestContext] can both call it.
shelf.Request checkRequestFraming(shelf.Request request) {
  if (_framingChecked[request] == true) return request;
  var checked = _checkFraming(request);
  _framingChecked[checked] = true;
  return checked;
}

final Expando<bool> _framingChecked = Expando('framingChecked');

shelf.Request _checkFraming(shelf.Request request) {
  var contentLength = request.headers[HttpHeaders.contentLengthHeader];
  var transferEncoding = request.headers[HttpHeaders.transferEncodingHeader];

  if (transferEncoding != null) {
    if (contentLength != null) {
      throw AngelHttpException.badRequest(
        message: 'Content-Length and Transfer-Encoding cannot both be sent.',
      );
    }
    // shelf joins repeated headers with ','. chunked must come last, once.
    var codings = transferEncoding
        .split(',')
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty)
        .toList();
    if (codings.isEmpty ||
        codings.last != 'chunked' ||
        codings.indexOf('chunked') != codings.length - 1) {
      throw AngelHttpException.badRequest(
        message: 'Invalid Transfer-Encoding: $transferEncoding',
      );
    }
    return request;
  }

  if (contentLength == null) return request;

  var lengths = contentLength
      .split(',')
      .map((v) => MockHttpHeaders.tryParseContentLength(v.trim()))
      .toSet();
  if (lengths.length != 1 || lengths.first == null) {
    throw AngelHttpException.badRequest(
      message: 'Invalid Content-Length: $contentLength',
    );
  }

  var length = '${lengths.first}';
  if (length == contentLength) return request;
  return request.change(headers: {HttpHeaders.contentLengthHeader: length});
}
