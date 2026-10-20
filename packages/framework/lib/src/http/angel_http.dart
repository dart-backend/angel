import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show
        Cookie,
        HttpRequest,
        HttpResponse,
        HttpException,
        HttpServer,
        Platform,
        SecurityContext;

import 'package:angel3_framework/angel3_framework.dart';

import '../core/core.dart';
import 'http_request_context.dart';
import 'http_response_context.dart';

final RegExp _straySlashes = RegExp(r'(^/+)|(/+$)');

typedef ServerGeneratorType = Future<HttpServer> Function(dynamic, int);

/// Adapts `dart:io`'s [HttpServer] to serve Angel.
class AngelHttp
    extends
        Driver<
          HttpRequest,
          HttpResponse,
          HttpServer,
          HttpRequestContext,
          HttpResponseContext
        > {
  @override
  Uri get uri {
    return Uri(
      scheme: _secure ? 'https' : 'http',
      host: server?.address.address,
      port: server?.port,
    );
  }

  final bool _secure;

  AngelHttp._(
    super.app,
    super.serverGenerator,
    bool useZone, [
    this._secure = false,
  ]) : super(useZone: useZone);

  factory AngelHttp(Angel app, {bool useZone = true}) {
    return AngelHttp._(app, HttpServer.bind, useZone);
  }

  /// An instance mounted on a server started by the [serverGenerator].
  factory AngelHttp.custom(
    Angel app,
    ServerGeneratorType serverGenerator, {
    bool useZone = true,
    Map<String, String> headers = const {},
  }) {
    return AngelHttp._(app, serverGenerator, useZone);
  }

  factory AngelHttp.fromSecurityContext(
    Angel app,
    SecurityContext context, {
    bool useZone = true,
  }) {
    return AngelHttp._(
      app,
      (address, int port) {
        return HttpServer.bindSecure(address, port, context);
      },
      useZone,
      true,
    );
  }

  /// Creates an HTTPS server.
  ///
  /// Provide paths to a certificate chain and server key (both .pem).
  /// If no password is provided, a random one will be generated upon running
  /// the server.
  factory AngelHttp.secure(
    Angel app,
    String certificateChainPath,
    String serverKeyPath, {
    String? password,
    bool useZone = true,
  }) {
    var certificateChain = Platform.script
        .resolve(certificateChainPath)
        .toFilePath();
    var serverKey = Platform.script.resolve(serverKeyPath).toFilePath();
    var serverContext = SecurityContext();
    serverContext.useCertificateChain(certificateChain, password: password);
    serverContext.usePrivateKey(serverKey, password: password);

    return AngelHttp.fromSecurityContext(app, serverContext, useZone: useZone);
  }

  /// Handles [request], for use with a server created outside of
  /// [startServer]. Like [handleRawRequestSafely], the returned future never
  /// fails: a malformed request gets `400 Bad Request`, and an error in the
  /// server `500 Internal Server Error`; both are logged.
  Future handleRequest(HttpRequest request) =>
      handleRawRequestSafely(request, request.response);

  @override
  void addCookies(HttpResponse response, Iterable<Cookie> cookies) =>
      response.cookies.addAll(cookies);

  @override
  Future<void> close() async {
    return await super.close();
  }

  /// Remove headers from HTTP Response
  void removeResponseHeader(Map<String, Object> headers) {
    headers.forEach((key, value) {
      server?.defaultResponseHeaders.remove(key, value);
    });
  }

  /// Add headers to HTTP Response
  void addResponseHeader(Map<String, Object> headers) {
    headers.forEach((key, value) {
      server?.defaultResponseHeaders.add(key, value);
    });
  }

  @override
  Future<void> closeServer(HttpServer server) => server.close(force: true);

  /// Waits until `dart:io` has closed every connection, as it does once its
  /// response is sent.
  @override
  Future<void> connectionsClosed() async {
    var server = this.server;
    while (server != null && server.connectionsInfo().total > 0) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  @override
  Future closeResponse(HttpResponse response) => response.close();

  @override
  Future<HttpRequestContext> createRequestContext(
    HttpRequest request,
    HttpResponse response,
  ) {
    var path = request.uri.path.replaceAll(_straySlashes, '');
    if (path.isEmpty) path = '/';
    return HttpRequestContext.from(request, app, path);
  }

  @override
  Future<HttpResponseContext> createResponseContext(
    HttpRequest request,
    HttpResponse response, [
    HttpRequestContext? correspondingRequest,
  ]) {
    var context = HttpResponseContext(response, app, correspondingRequest);
    context.serializer = (app.serializer ?? json.encode);
    context.encoders.addAll(app.encoders);
    return Future<HttpResponseContext>.value(context);
  }

  @override
  Stream<HttpResponse> createResponseStreamFromRawRequest(
    HttpRequest request,
  ) => Stream.fromIterable([request.response]);

  /// Asking for chunked encoding on an HTTP/1.0 response is ignored, as
  /// those clients cannot receive it (see [supportsChunkedEncoding]); any
  /// other failure is thrown.
  @override
  void setChunkedEncoding(HttpResponse response, bool value) {
    try {
      response.headers.chunkedTransferEncoding = value;
    } on HttpException catch (e) {
      // dart:io reports HTTP/1.0 only through this message.
      if (!value || !e.message.contains('HTTP 1.0')) rethrow;
    }
  }

  /// HTTP/1.0 has no chunked encoding; Content-Length is sent instead.
  @override
  bool supportsChunkedEncoding(HttpRequest request) =>
      request.protocolVersion != '1.0';

  @override
  void setContentLength(HttpResponse response, int length) =>
      response.headers.contentLength = length;

  @override
  void setHeader(HttpResponse response, String key, String value) =>
      response.headers.set(key, value);

  @override
  void setStatusCode(HttpResponse response, int value) =>
      response.statusCode = value;

  @override
  void writeStringToResponse(HttpResponse response, String value) =>
      response.write(value);

  @override
  void writeToResponse(HttpResponse response, List<int> data) =>
      response.add(data);
}
