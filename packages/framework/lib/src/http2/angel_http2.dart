import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart' hide Header;
import 'package:angel3_framework/http.dart';
import 'package:http2/transport.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';

import '../http/connections.dart';
import '../http/headers.dart';
import 'default_headers.dart';
import 'http2_request_context.dart';
import 'http2_response_context.dart';

import 'package:uuid/uuid.dart';

/// Boots a shared server instance. Use this if launching multiple isolates.
Future<SecureServerSocket> startSharedHttp2(
  Object? address,
  int port,
  SecurityContext ctx,
) {
  return SecureServerSocket.bind(address, port, ctx, shared: true);
}

/// Adapts `package:http2`'s [ServerTransportConnection] to serve Angel.
class AngelHttp2
    extends
        Driver<
          Socket,
          ServerTransportStream,
          SecureServerSocket,
          Http2RequestContext,
          Http2ResponseContext
        > {
  final ServerSettings? settings;
  AngelHttp? _http;
  final StreamController<HttpRequest> _onHttp1 = StreamController();
  final Map<String, MockHttpSession> _sessions = {};
  final Map<String, DateTime> _sessionLastSeen = {};
  DateTime _lastSessionPrune = DateTime.now();
  final Uuid _uuid = Uuid();
  _AngelHttp2ServerSocket? _artificial;

  /// The open HTTP/2 connections, which [drain] lets finish.
  final Set<ServerTransportConnection> _connections = {};

  /// The status, headers and cookies the driver sets on a stream (for a
  /// buffered response, or an error fallback). HTTP/2 needs them in one
  /// HEADERS frame that starts with `:status`, so they are collected here and
  /// sent before the first DATA frame, or on [closeResponse].
  final Expando<_PendingHeaders> _pending = Expando();

  /// How long a session may go unused before it is discarded.
  ///
  /// Expired sessions are pruned periodically (at least every minute, or
  /// every [sessionTimeout] if shorter), so the session store does not grow
  /// without bound. Defaults to 20 minutes, like `dart:io`'s `HttpServer`.
  final Duration sessionTimeout;

  static const Duration _maxPruneInterval = Duration(minutes: 1);

  SecureServerSocket? get socket => _artificial;

  AngelHttp2._(
    Angel app,
    Future<SecureServerSocket> Function(dynamic, int) serverGenerator,
    bool useZone,
    bool allowHttp1,
    this.settings,
    this.sessionTimeout,
  ) : super(app, serverGenerator, useZone: useZone) {
    if (allowHttp1) {
      final http = _http = AngelHttp(app, useZone: useZone);
      onHttp1.listen(http.handleRequest);
    }
  }

  factory AngelHttp2(
    Angel app,
    SecurityContext securityContext, {
    bool useZone = true,
    bool allowHttp1 = false,
    ServerSettings? settings,
    Duration sessionTimeout = const Duration(minutes: 20),
  }) {
    return AngelHttp2.custom(
      app,
      securityContext,
      SecureServerSocket.bind,
      useZone: useZone,
      allowHttp1: allowHttp1,
      settings: settings,
      sessionTimeout: sessionTimeout,
    );
  }

  factory AngelHttp2.custom(
    Angel app,
    SecurityContext ctx,
    Future<SecureServerSocket> Function(
      InternetAddress? address,
      int port,
      SecurityContext ctx,
    )
    serverGenerator, {
    bool useZone = true,
    bool allowHttp1 = false,
    ServerSettings? settings,
    Duration sessionTimeout = const Duration(minutes: 20),
  }) {
    return AngelHttp2._(
      app,
      (address, port) {
        var addr = address is InternetAddress
            ? address
            : InternetAddress(address.toString());
        return Future.sync(() => serverGenerator(addr, port, ctx));
      },
      useZone,
      allowHttp1,
      settings,
      sessionTimeout,
    );
  }

  /// Fires when an HTTP/1.x request is received.
  Stream<HttpRequest> get onHttp1 => _onHttp1.stream;

  /// The default headers of HTTP/2 responses.
  final DefaultResponseHeaders _http2Defaults = DefaultResponseHeaders();

  /// The changes to the default headers, which the server of the HTTP/1
  /// requests that [allowHttp1] serves gets as it starts.
  final List<void Function(HttpHeaders)> _http1Defaults = [];

  /// Adds default headers to the responses, HTTP/2 ones and those of the
  /// HTTP/1 requests that [allowHttp1] serves, by the rules of
  /// [AngelHttp.addResponseHeader]: a header that a handler sets replaces one
  /// of the same name. Unlike that one, it may be called before
  /// [startServer] too.
  ///
  /// A header that cannot be sent throws an [ArgumentError], and none of
  /// [headers] is added.
  void addResponseHeader(Map<String, Object?> headers) {
    var copy = copyHeaders(headers);
    checkHeaders(copy);
    _changeHttp1Defaults((d) => d.addValues(copy));
    _http2Defaults.add(copy);
  }

  /// Removes default headers of the responses, by the rules of
  /// [AngelHttp.removeResponseHeader], including those that `dart:io` adds
  /// to the HTTP/1 ones. Like [addResponseHeader], it may be called before
  /// [startServer] too.
  void removeResponseHeader(Map<String, Object?> headers) {
    var copy = copyHeaders(headers);
    copy.keys.forEach(checkHeaderName);
    _changeHttp1Defaults((d) => d.removeValues(copy));
    _http2Defaults.remove(copy);
  }

  /// Applies [change] to the HTTP/1 server running, if any, and keeps it for
  /// the server started next. The running server changes first, so that a
  /// change it does not take changes nothing.
  void _changeHttp1Defaults(void Function(HttpHeaders) change) {
    var defaults = _artificial?.http1.defaultResponseHeaders;
    if (defaults != null) change(defaults);
    _http1Defaults.add(change);
  }

  @override
  Future<SecureServerSocket> generateServer([
    Object? address,
    int? port,
  ]) async {
    var s = await serverGenerator(address ?? '127.0.0.1', port ?? 0);
    var artificial = _artificial = _AngelHttp2ServerSocket(s, this);
    for (var change in _http1Defaults) {
      change(artificial.http1.defaultResponseHeaders);
    }
    return artificial;
  }

  Future<void>? _drainingHttp2;

  /// Drains HTTP/1 requests too, which [allowHttp1] serves. Calling it again
  /// returns the same future.
  @override
  Future<void> drain() => _drainingHttp2 ??= _drainHttp2();

  Future<void> _drainHttp2() async {
    await _artificial?.close();
    var http = _http?..closeTimeout = closeTimeout;
    await Future.wait([super.drain(), ?http?.drain()]);
  }

  /// The headers of [pending], with the defaults it has none of.
  List<Header> _headersOf(_PendingHeaders pending) =>
      pending.toHeaders(_http2Defaults);

  _PendingHeaders _pendingFor(ServerTransportStream response) =>
      _pending[response] ??= _PendingHeaders();

  @override
  void addCookies(ServerTransportStream response, Iterable<Cookie> cookies) {
    _pendingFor(response).cookies.addAll(cookies);
  }

  /// Also closes the connections still open, HTTP/2 and HTTP/1.
  @override
  Future<void> closeServer(SecureServerSocket server) async {
    await server.close();
    await _artificial?.http1.close(force: true);
    await Future.wait([
      for (var connection in _connections.toList())
        connection.terminate().catchError((_) {}),
    ]);
  }

  /// Ends each HTTP/2 connection once its streams are done (with a GOAWAY),
  /// and waits for the HTTP/1 connections to close too.
  @override
  Future<void> connectionsClosed() async {
    var http1 = _artificial?.http1;
    await Future.wait([
      for (var connection in _connections.toList())
        connection.finish().catchError((_) {}),
      if (http1 != null) allConnectionsClosed(http1),
    ]);
  }

  /// Ends a stream the driver wrote to (see [_pending]). A stream it never
  /// wrote to is reset instead, since no valid response can be sent on it, as
  /// is one whose [Http2ResponseContext] sent its own headers but not those of
  /// the driver (e.g. an error fallback after a response started streaming).
  @override
  Future closeResponse(ServerTransportStream response) {
    var pending = _pending[response];
    if (pending == null ||
        (!pending.sent && Http2ResponseContext.sentHeaders(response))) {
      response.terminate();
    } else if (!pending.closed) {
      pending.closed = true;
      if (pending.sent) {
        return response.outgoingMessages.close();
      }
      pending.sent = true;
      response.sendHeaders(_headersOf(pending), endStream: true);
    }
    return Future.value();
  }

  @override
  Future sendResponse(
    Socket request,
    ServerTransportStream response,
    RequestContext req,
    ResponseContext res, {
    bool ignoreFinalizers = false,
  }) {
    // An unbuffered Http2ResponseContext adds this itself when it sends its
    // headers; a buffered one is sent by the driver. The cookie goes on after
    // the response finalizers, which may be the first to read `req.session`.
    if (!res.isBuffered || res is! Http2ResponseContext) {
      return super.sendResponse(
        request,
        response,
        req,
        res,
        ignoreFinalizers: ignoreFinalizers,
      );
    }
    var finalizers = ignoreFinalizers ? Future.value() : res.runFinalizers(req);
    return finalizers.then((_) {
      res.addSessionCookie();
      if (req is Http2RequestContext) req.markHeadersSent();
      return super.sendResponse(
        request,
        response,
        req,
        res,
        ignoreFinalizers: true,
      );
    });
  }

  @override
  Future<Http2RequestContext> createRequestContext(
    Socket request,
    ServerTransportStream response,
  ) async {
    _pruneSessions();
    var req = await Http2RequestContext.from(
      response,
      request,
      app,
      _sessions,
      _uuid,
      onSessionCreated: (session) =>
          _sessionLastSeen[session.id] = DateTime.now(),
    );
    // Reading `req.session` here would create a session for every request.
    if (req.hasSession) _sessionLastSeen[req.session!.id] = DateTime.now();
    return req;
  }

  /// Discards sessions unused for longer than [sessionTimeout].
  void _pruneSessions() {
    var now = DateTime.now();
    var interval = sessionTimeout < _maxPruneInterval
        ? sessionTimeout
        : _maxPruneInterval;
    if (now.difference(_lastSessionPrune) < interval) return;
    _lastSessionPrune = now;

    _sessionLastSeen.removeWhere((id, lastSeen) {
      var expired = now.difference(lastSeen) > sessionTimeout;
      if (expired) _sessions.remove(id);
      return expired;
    });
  }

  @override
  Future<Http2ResponseContext> createResponseContext(
    Socket request,
    ServerTransportStream response, [
    Http2RequestContext? correspondingRequest,
  ]) async {
    return Http2ResponseContext(
        app,
        response,
        correspondingRequest,
        defaultHeaders: _http2Defaults,
      )
      ..serializer = (app.serializer ?? json.encode)
      ..encoders.addAll(app.encoders);
  }

  @override
  Stream<ServerTransportStream> createResponseStreamFromRawRequest(
    Socket request,
  ) {
    var connection = ServerTransportConnection.viaSocket(
      request,
      settings: settings,
    );
    _connections.add(connection);
    request.done
        .then((_) {}, onError: (_) {})
        .whenComplete(() => _connections.remove(connection));
    return connection.incomingStreams;
  }

  @override
  void setChunkedEncoding(ServerTransportStream response, bool value) {
    // Do nothing in HTTP/2
  }

  @override
  void setContentLength(ServerTransportStream response, int length) {
    setHeader(response, 'content-length', length.toString());
  }

  @override
  void setHeader(ServerTransportStream response, String key, String? value) {
    // HTTP/2 header names must be lowercase.
    _pendingFor(response).headers[key.toLowerCase()] = value!;
  }

  @override
  void setStatusCode(ServerTransportStream response, int value) {
    _pendingFor(response).statusCode = value;
  }

  @override
  Uri get uri => Uri(
    scheme: 'https',
    host: server?.address.address,
    port: server?.port != 443 ? server?.port : null,
  );

  @override
  void writeStringToResponse(ServerTransportStream response, String value) {
    writeToResponse(response, utf8.encode(value));
  }

  @override
  void writeToResponse(ServerTransportStream response, List<int> data) {
    var pending = _pendingFor(response);
    if (!pending.sent) {
      pending.sent = true;
      response.sendHeaders(_headersOf(pending));
    }
    response.sendData(data);
  }
}

class _PendingHeaders {
  int statusCode = 200;
  final Map<String, String> headers = {};
  final List<Cookie> cookies = [];
  bool sent = false, closed = false;

  List<Header> toHeaders(DefaultResponseHeaders defaults) => [
    Header.ascii(':status', statusCode.toString()),
    for (var entry in headers.entries) Header.ascii(entry.key, entry.value),
    ...defaults.headersFor({for (var name in headers.keys) name.toLowerCase()}),
    for (var cookie in cookies) Header.ascii('set-cookie', cookie.toString()),
  ];
}

class _FakeServerSocket extends Stream<Socket> implements ServerSocket {
  final _AngelHttp2ServerSocket angel;
  final _ctrl = StreamController<Socket>();

  _FakeServerSocket(this.angel);

  @override
  InternetAddress get address => angel.address;

  @override
  Future<ServerSocket> close() async {
    await (_ctrl.close());
    return this;
  }

  @override
  int get port => angel.port;

  @override
  StreamSubscription<Socket> listen(
    void Function(Socket event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _ctrl.stream.listen(
      onData,
      cancelOnError: cancelOnError,
      onError: onError,
      onDone: onDone,
    );
  }
}

class _AngelHttp2ServerSocket extends Stream<SecureSocket>
    implements SecureServerSocket {
  final SecureServerSocket socket;
  final AngelHttp2 driver;
  final _ctrl = StreamController<SecureSocket>();
  late _FakeServerSocket _fake;
  StreamSubscription? _sub;

  /// The server of the HTTP/1 connections.
  late final HttpServer http1;

  _AngelHttp2ServerSocket(this.socket, this.driver) {
    _fake = _FakeServerSocket(this);
    http1 = HttpServer.listenOn(_fake);
    http1.pipe(driver._onHttp1);
    _sub = socket.listen(
      (socket) {
        if (socket.selectedProtocol == null ||
            socket.selectedProtocol == 'http/1.0' ||
            socket.selectedProtocol == 'http/1.1') {
          // Without allowHttp1 (or a listener on onHttp1), nothing would
          // ever answer the connection, and it would be buffered forever.
          if (driver._onHttp1.hasListener) {
            _fake._ctrl.add(socket);
          } else {
            socket.destroy();
          }
        } else if (socket.selectedProtocol == 'h2' ||
            socket.selectedProtocol == 'h2-14') {
          _ctrl.add(socket);
        } else {
          socket.destroy();
          throw Exception(
            'AngelHttp2 does not support ${socket.selectedProtocol} as an ALPN protocol.',
          );
        }
      },
      onDone: _ctrl.close,
      onError: (e, st) {
        driver.app.logger.warning(
          'HTTP/2 incoming connection failure: ',
          e,
          st as StackTrace,
        );
      },
    );
  }

  @override
  InternetAddress get address => socket.address;

  @override
  int get port => socket.port;

  @override
  Future<SecureServerSocket> close() {
    _sub?.cancel();
    _fake.close();
    _ctrl.close();
    return socket.close();
  }

  @override
  StreamSubscription<SecureSocket> listen(
    void Function(SecureSocket event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _ctrl.stream.listen(
      onData,
      cancelOnError: cancelOnError,
      onError: onError,
      onDone: onDone,
    );
  }
}
