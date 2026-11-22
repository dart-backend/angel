import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart' hide Header;
import 'package:angel3_framework/http.dart';
import 'package:angel3_framework/http2.dart';
import 'package:angel3_framework/src/http/bind_secure.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:http2/transport.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

const _fixtures = 'test/fixtures/mtls';

/// The context of a server that trusts the client certificates of the test
/// CA, as [SecurityContext.setClientAuthorities] and
/// [SecurityContext.setTrustedCertificates] have it.
SecurityContext _serverContext({bool h2 = false}) {
  var ctx = SecurityContext()
    ..useCertificateChain('dev.pem')
    ..usePrivateKey('dev.key', password: 'dartdart')
    ..setClientAuthorities('$_fixtures/ca.pem')
    ..setTrustedCertificates('$_fixtures/ca.pem');
  if (h2) ctx.setAlpnProtocols(['h2', 'http/1.1'], true);
  return ctx;
}

/// The context of a client of the certificate [name], or of none.
SecurityContext _clientContext([String? name]) {
  var ctx = SecurityContext();
  if (name != null) {
    ctx
      ..useCertificateChain('$_fixtures/$name.pem')
      ..usePrivateKey('$_fixtures/$name.key');
  }
  return ctx;
}

/// The body of a GET of [uri] over HTTP/1.1, of the certificate [name].
Future<String> _get(Uri uri, [String? name]) async {
  var client = HttpClient(context: _clientContext(name))
    ..badCertificateCallback = (_, _, _) => true;
  try {
    var request = await client.getUrl(uri);
    var response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

/// The body of a GET of [path] over HTTP/2, of the certificate [name].
Future<String> _getH2(int port, String path, [String? name]) async {
  var socket = await SecureSocket.connect(
    '127.0.0.1',
    port,
    context: _clientContext(name),
    onBadCertificate: (_) => true,
    supportedProtocols: ['h2'],
  );
  var connection = ClientTransportConnection.viaSocket(socket);
  try {
    var stream = connection.makeRequest([
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', path),
      Header.ascii(':scheme', 'https'),
      Header.ascii(':authority', '127.0.0.1:$port'),
    ], endStream: true);
    var body = <int>[];
    await for (var message in stream.incomingMessages) {
      if (message is DataStreamMessage) body.addAll(message.bytes);
    }
    return utf8.decode(body);
  } finally {
    await connection.finish();
    socket.destroy();
  }
}

/// The bytes that a server on [port] sends over HTTP/2 to a client of the
/// certificate [name], or of none, before it closes the connection.
///
/// Of TLS 1.3, the client's side of the handshake ends before the server
/// checks its certificate: a server that refuses it closes the connection,
/// without a byte of HTTP/2.
Future<List<int>> _receivedOverH2(int port, [String? name]) async {
  var socket = await SecureSocket.connect(
    '127.0.0.1',
    port,
    context: _clientContext(name),
    onBadCertificate: (_) => true,
    supportedProtocols: ['h2'],
  );
  var received = <int>[];
  await socket
      .listen(received.addAll)
      .asFuture<void>()
      .catchError((_) {})
      .timeout(const Duration(seconds: 10));
  socket.destroy();
  return received;
}

/// An app that answers the subject of the request's client certificate, or
/// `none`.
Angel _app() =>
    Angel()
      ..get('/cert', (req, res) => req.clientCertificate?.subject ?? 'none');

/// A request whose connection closed before its context was made: dart:io
/// throws a TypeError of the certificate of a closed, undestroyed socket.
class _ClosedRequest extends MockHttpRequest {
  _ClosedRequest() : super('GET', Uri.parse('/'));

  @override
  X509Certificate? get certificate => throw TypeError();
}

/// The socket of an HTTP/2 connection that closed, as [_ClosedRequest].
class _ClosedSocket implements SecureSocket {
  @override
  InternetAddress get address => InternetAddress.loopbackIPv4;

  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;

  @override
  int get port => 443;

  @override
  X509Certificate? get peerCertificate => throw TypeError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An HTTP/2 stream of a GET of `/`.
class _Stream implements ServerTransportStream {
  @override
  Stream<StreamMessage> get incomingMessages => Stream.value(
    HeadersStreamMessage([
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', '/'),
      Header.ascii(':scheme', 'https'),
      Header.ascii(':authority', 'localhost'),
    ], endStream: true),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AngelHttp', () {
    late AngelHttp http;
    late Uri uri;

    Future<void> start({required bool request}) async {
      http = AngelHttp.fromSecurityContext(
        _app(),
        _serverContext(),
        requestClientCertificate: request,
      );
      var server = await http.startServer('127.0.0.1', 0);
      uri = Uri.parse('https://127.0.0.1:${server.port}/cert');
    }

    tearDown(() => http.close());

    test('gives the certificate a client presents', () async {
      await start(request: true);
      expect(await _get(uri, 'client'), '"/CN=test-client/O=Angel3"');
    });

    test('lets a client without a certificate connect', () async {
      await start(request: true);
      expect(await _get(uri), '"none"');
    });

    test('refuses a certificate that does not verify', () async {
      await start(request: true);
      await expectLater(_get(uri, 'rogue'), throwsA(anything));
    });

    test('asks for none by default', () async {
      await start(request: false);
      expect(await _get(uri, 'client'), '"none"');
    });
  });

  group('AngelHttp2', () {
    late AngelHttp2 http2;
    late int port;

    Future<void> start({required bool request}) async {
      http2 = AngelHttp2(
        _app(),
        _serverContext(h2: true),
        allowHttp1: true,
        requestClientCertificate: request,
      );
      port = (await http2.startServer('127.0.0.1', 0)).port;
    }

    tearDown(() => http2.close());

    test('gives the certificate of an HTTP/2 request', () async {
      await start(request: true);
      expect(
        await _getH2(port, '/cert', 'client'),
        '"/CN=test-client/O=Angel3"',
      );
    });

    test('gives the certificate of an HTTP/1 request of allowHttp1', () async {
      await start(request: true);
      var uri = Uri.parse('https://127.0.0.1:$port/cert');
      expect(await _get(uri, 'client'), '"/CN=test-client/O=Angel3"');
    });

    test('lets a client without a certificate connect', () async {
      await start(request: true);
      expect(await _getH2(port, '/cert'), '"none"');
    });

    test('refuses a certificate that does not verify', () async {
      await start(request: true);
      expect(await _receivedOverH2(port, 'rogue'), isEmpty);
    });

    test('asks for none by default', () async {
      await start(request: false);
      expect(await _getH2(port, '/cert', 'client'), '"none"');
    });
  });

  group('requireClientCertificate', () {
    test('lets a client of a certificate connect over HTTP/1', () async {
      var http = AngelHttp.fromSecurityContext(
        _app(),
        _serverContext(),
        requireClientCertificate: true,
      );
      var server = await http.startServer('127.0.0.1', 0);
      addTearDown(http.close);
      var uri = Uri.parse('https://127.0.0.1:${server.port}/cert');
      expect(await _get(uri, 'client'), '"/CN=test-client/O=Angel3"');
    });

    test('refuses a client without a certificate over HTTP/1', () async {
      var http = AngelHttp.fromSecurityContext(
        _app(),
        _serverContext(),
        requireClientCertificate: true,
      );
      var server = await http.startServer('127.0.0.1', 0);
      addTearDown(http.close);
      var uri = Uri.parse('https://127.0.0.1:${server.port}/cert');
      await expectLater(_get(uri), throwsA(anything));
    });

    test('frees the port when the server closes', () async {
      var http = AngelHttp.fromSecurityContext(
        _app(),
        _serverContext(),
        requireClientCertificate: true,
      );
      var port = (await http.startServer('127.0.0.1', 0)).port;
      await http.close();
      var socket = await ServerSocket.bind('127.0.0.1', port);
      await socket.close();
    });

    test('frees the port when its HttpServer closes', () async {
      var server = await bindSecure(
        '127.0.0.1',
        0,
        _serverContext(),
        requireClientCertificate: true,
      );
      var port = server.port;
      server.listen((_) {});
      await server.close(force: true);
      var socket = await ServerSocket.bind('127.0.0.1', port);
      await socket.close();
    });

    test('is passed on by startSharedSecure', () async {
      var http = AngelHttp.custom(
        _app(),
        startSharedSecure(_serverContext(), requireClientCertificate: true),
      );
      var server = await http.startServer('127.0.0.1', 0);
      addTearDown(http.close);
      var uri = Uri.parse('https://127.0.0.1:${server.port}/cert');
      expect(await _get(uri, 'client'), '"/CN=test-client/O=Angel3"');
      await expectLater(_get(uri), throwsA(anything));
    });

    test('is passed on by AngelHttp.secure', () async {
      String path(String file) => File(file).absolute.path;
      var http = AngelHttp.secure(
        _app(),
        path('dev.pem'),
        path('dev.key'),
        password: 'dartdart',
        requireClientCertificate: true,
        clientAuthoritiesPath: path('$_fixtures/ca.pem'),
      );
      var server = await http.startServer('127.0.0.1', 0);
      addTearDown(http.close);
      var uri = Uri.parse('https://127.0.0.1:${server.port}/cert');
      expect(await _get(uri, 'client'), '"/CN=test-client/O=Angel3"');
      await expectLater(_get(uri), throwsA(anything));
    });

    test('refuses a client without a certificate over HTTP/2', () async {
      var http2 = AngelHttp2(
        _app(),
        _serverContext(h2: true),
        requireClientCertificate: true,
      );
      var port = (await http2.startServer('127.0.0.1', 0)).port;
      addTearDown(http2.close);
      expect(
        await _getH2(port, '/cert', 'client'),
        '"/CN=test-client/O=Angel3"',
      );
      expect(await _receivedOverH2(port), isEmpty);
    });

    test('is passed on by startSharedHttp2', () async {
      var http2 = AngelHttp2.custom(
        _app(),
        _serverContext(h2: true),
        (address, port, ctx) => startSharedHttp2(
          address,
          port,
          ctx,
          requireClientCertificate: true,
        ),
      );
      var port = (await http2.startServer('127.0.0.1', 0)).port;
      addTearDown(http2.close);
      expect(
        await _getH2(port, '/cert', 'client'),
        '"/CN=test-client/O=Angel3"',
      );
      expect(await _receivedOverH2(port), isEmpty);
    });
  });

  group('after the connection closes', () {
    /// An app whose `/late` closes the response, waits for the connection
    /// to close, and then completes [subject] with the certificate's.
    Angel lateApp(Completer<String> subject) =>
        Angel()..get('/late', (req, res) async {
          await res.close();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          try {
            subject.complete(req.clientCertificate?.subject ?? 'none');
          } catch (e) {
            subject.complete('threw: $e');
          }
        });

    test('still gives the certificate of an HTTP/1 request', () async {
      var subject = Completer<String>();
      var http = AngelHttp.fromSecurityContext(
        lateApp(subject),
        _serverContext(),
        requestClientCertificate: true,
      );
      var server = await http.startServer('127.0.0.1', 0);
      addTearDown(http.close);
      var socket = await SecureSocket.connect(
        '127.0.0.1',
        server.port,
        context: _clientContext('client'),
        onBadCertificate: (_) => true,
      );
      // The server closes the connection once it has responded.
      socket.write(
        'GET /late HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
      );
      await socket.drain<void>().catchError((_) {});
      expect(await subject.future, '/CN=test-client/O=Angel3');
    });

    test('still gives the certificate of an HTTP/2 request', () async {
      var subject = Completer<String>();
      var http2 = AngelHttp2(
        lateApp(subject),
        _serverContext(h2: true),
        requestClientCertificate: true,
      );
      var port = (await http2.startServer('127.0.0.1', 0)).port;
      addTearDown(http2.close);
      // _getH2 destroys the connection once it has the response.
      await _getH2(port, '/late', 'client');
      expect(await subject.future, '/CN=test-client/O=Angel3');
    });
  });

  group('AngelHttp.secure', () {
    late AngelHttp http;
    late Uri uri;

    setUp(() async {
      // Absolute, as AngelHttp.secure resolves paths of Platform.script.
      String path(String file) => File(file).absolute.path;
      http = AngelHttp.secure(
        _app(),
        path('dev.pem'),
        path('dev.key'),
        password: 'dartdart',
        requestClientCertificate: true,
        clientAuthoritiesPath: path('$_fixtures/ca.pem'),
      );
      var server = await http.startServer('127.0.0.1', 0);
      uri = Uri.parse('https://127.0.0.1:${server.port}/cert');
    });

    tearDown(() => http.close());

    test('trusts the certificates of clientAuthoritiesPath', () async {
      expect(await _get(uri, 'client'), '"/CN=test-client/O=Angel3"');
    });

    test('refuses a certificate that they did not sign', () async {
      await expectLater(_get(uri, 'rogue'), throwsA(anything));
    });
  });

  test('startSharedSecure asks for one of requestClientCertificate', () async {
    var http = AngelHttp.custom(
      _app(),
      startSharedSecure(_serverContext(), requestClientCertificate: true),
    );
    var server = await http.startServer('127.0.0.1', 0);
    addTearDown(http.close);
    var uri = Uri.parse('https://127.0.0.1:${server.port}/cert');
    expect(await _get(uri, 'client'), '"/CN=test-client/O=Angel3"');
  });

  test('startSharedHttp2 asks for one of requestClientCertificate', () async {
    var http2 = AngelHttp2.custom(
      _app(),
      _serverContext(h2: true),
      (address, port, ctx) =>
          startSharedHttp2(address, port, ctx, requestClientCertificate: true),
    );
    var port = (await http2.startServer('127.0.0.1', 0)).port;
    addTearDown(http2.close);
    expect(await _getH2(port, '/cert', 'client'), '"/CN=test-client/O=Angel3"');
  });

  test('is null for a plain HTTP request', () async {
    var http = AngelHttp(_app());
    var server = await http.startServer('127.0.0.1', 0);
    addTearDown(http.close);
    expect(
      await _get(Uri.parse('http://127.0.0.1:${server.port}/cert')),
      '"none"',
    );
  });

  group('of a connection that closed before the request', () {
    test('is null for HTTP/1', () async {
      var req = await HttpRequestContext.from(_ClosedRequest(), Angel(), '/');
      expect(req.clientCertificate, isNull);
    });

    test('is null for HTTP/2', () async {
      var req = await Http2RequestContext.from(
        _Stream(),
        _ClosedSocket(),
        Angel(),
        {},
        const Uuid(),
      );
      expect(req.clientCertificate, isNull);
    });
  });

  test('is null for a mock request', () async {
    var http = AngelHttp(_app());
    var rq = MockHttpRequest('GET', Uri.parse('/cert'));
    await rq.close();
    await http.handleRequest(rq);
    var body = await rq.response.transform(utf8.decoder).join();
    expect(body, '"none"');
  });
}
