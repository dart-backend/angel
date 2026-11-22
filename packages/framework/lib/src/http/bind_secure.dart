import 'dart:async';
import 'dart:io';

/// Binds an HTTPS server, as [HttpServer.bindSecure], which cannot require a
/// client certificate: if [requireClientCertificate], a client that presents
/// none fails the TLS handshake.
Future<HttpServer> bindSecure(
  Object? address,
  int port,
  SecurityContext context, {
  bool requestClientCertificate = false,
  bool requireClientCertificate = false,
  bool shared = false,
}) async {
  if (!requireClientCertificate) {
    return HttpServer.bindSecure(
      address,
      port,
      context,
      requestClientCertificate: requestClientCertificate,
      shared: shared,
    );
  }
  var socket = await SecureServerSocket.bind(
    address,
    port,
    context,
    requireClientCertificate: true,
    shared: shared,
  );
  return _SocketClosingHttpServer(
    HttpServer.listenOn(_SecureServerSocketView(socket)),
    socket,
  );
}

/// A [SecureServerSocket] as the [ServerSocket] of [HttpServer.listenOn].
class _SecureServerSocketView extends StreamView<Socket>
    implements ServerSocket {
  final SecureServerSocket _socket;

  _SecureServerSocketView(this._socket) : super(_socket);

  @override
  InternetAddress get address => _socket.address;

  @override
  int get port => _socket.port;

  @override
  Future<ServerSocket> close() async {
    await _socket.close();
    return this;
  }
}

/// An [HttpServer] of [HttpServer.listenOn] that closes its socket when it
/// closes, or its subscription is cancelled (as of `Driver.drain`), as the
/// server of [HttpServer.bindSecure] does: [HttpServer.listenOn] leaves it
/// open.
class _SocketClosingHttpServer extends StreamView<HttpRequest>
    implements HttpServer {
  final HttpServer _server;
  final SecureServerSocket _socket;

  _SocketClosingHttpServer(this._server, this._socket)
    : super(_closingOnCancel(_server, _socket));

  static Stream<HttpRequest> _closingOnCancel(
    HttpServer server,
    SecureServerSocket socket,
  ) {
    late StreamController<HttpRequest> controller;
    late StreamSubscription<HttpRequest> subscription;
    controller = StreamController(
      sync: true,
      onListen: () => subscription = server.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      ),
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () async {
        await subscription.cancel();
        await socket.close();
      },
    );
    return controller.stream;
  }

  @override
  Future close({bool force = false}) async {
    await _socket.close();
    await _server.close(force: force);
  }

  @override
  String? get serverHeader => _server.serverHeader;

  @override
  set serverHeader(String? value) => _server.serverHeader = value;

  @override
  HttpHeaders get defaultResponseHeaders => _server.defaultResponseHeaders;

  @override
  bool get autoCompress => _server.autoCompress;

  @override
  set autoCompress(bool value) => _server.autoCompress = value;

  @override
  Duration? get idleTimeout => _server.idleTimeout;

  @override
  set idleTimeout(Duration? value) => _server.idleTimeout = value;

  @override
  int get port => _server.port;

  @override
  InternetAddress get address => _server.address;

  @override
  set sessionTimeout(int timeout) => _server.sessionTimeout = timeout;

  @override
  HttpConnectionsInfo connectionsInfo() => _server.connectionsInfo();
}
