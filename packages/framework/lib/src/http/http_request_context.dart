import 'dart:async';
import 'dart:io';

import 'package:angel3_container/angel3_container.dart';
import 'package:http_parser/http_parser.dart';

import '../core/core.dart';

/// An implementation of [RequestContext] that wraps a [HttpRequest].
class HttpRequestContext extends RequestContext<HttpRequest?> {
  Container? _container;
  MediaType _contentType = MediaType("text", "plain");
  HttpRequest? _io;
  String? _override;
  String _path = '';

  @override
  Container? get container => _container;

  @override
  MediaType get contentType {
    return _contentType;
  }

  @override
  List<Cookie> get cookies {
    return rawRequest!.cookies;
  }

  @override
  HttpHeaders get headers {
    return rawRequest!.headers;
  }

  @override
  String get hostname {
    return rawRequest?.headers.value('host') ?? "localhost";
  }

  /// The underlying [HttpRequest] instance underneath this context.
  HttpRequest? get rawRequest => _io;

  @override
  Stream<List<int>>? get body => _io;

  @override
  String get method {
    return _override ?? originalMethod;
  }

  @override
  String get originalMethod {
    return rawRequest!.method;
  }

  @override
  String get path {
    return _path;
  }

  @override
  InternetAddress get remoteAddress {
    return rawRequest!.connectionInfo!.remoteAddress;
  }

  @override
  HttpSession get session {
    return rawRequest!.session;
  }

  @override
  Uri get uri {
    return rawRequest!.uri;
  }

  /// Magically transforms an [HttpRequest] into a [RequestContext].
  static Future<HttpRequestContext> from(
      HttpRequest request, Angel app, String path) {
    HttpRequestContext ctx = HttpRequestContext()
      .._container = app.container!.createChild();

    String override = request.method;

    if (app.allowMethodOverrides == true) {
      override =
          request.headers.value('x-http-method-override')?.toUpperCase() ??
              request.method;
    }

    ctx.app = app;
    ctx._contentType = request.headers.contentType == null
        ? MediaType("text", "plain")
        : MediaType.parse(request.headers.contentType.toString());
    ctx._override = override;

    /*
    // Faster way to get path
    List<int> _path = [];

    // Go up until we reach a ?
    for (int ch in request.uri.toString().codeUnits) {
      if (ch != $question)
        _path.add(ch);
      else
        break;
    }

    // Remove trailing slashes
    int lastSlash = -1;

    for (int i = _path.length - 1; i >= 0; i--) {
      if (_path[i] == $slash)
        lastSlash = i;
      else
        break;
    }

    if (lastSlash > -1)
      ctx._path = String.fromCharCodes(_path.take(lastSlash));
    else
      ctx._path = String.fromCharCodes(_path);
      */

    ctx._path = path;
    ctx._io = request;

    return Future.value(ctx);
  }

  @override
  Future close() {
    //_contentType = null;
    _io = null;
    _override = null;
    //_path = null;
    return super.close();
  }
}
