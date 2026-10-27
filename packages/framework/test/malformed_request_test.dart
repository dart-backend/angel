import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:test/test.dart';

void main() {
  late AngelHttp http;

  setUp(() async {
    var app = Angel()
      ..get('/', (req, res) => 'ok')
      ..post('/type', (req, res) => req.contentType.mimeType);
    http = AngelHttp(app);
    await http.startServer('127.0.0.1', 0);
  });

  tearDown(() => http.close());

  /// Sends [headers] in a raw request, so dart:io's own header parsing (which
  /// accepts values a client library would refuse to send) is what the
  /// server sees.
  Future<(int, String)> send(
    String method,
    String path,
    List<String> headers, {
    int? port,
  }) async {
    var socket = await Socket.connect('127.0.0.1', port ?? http.uri.port);
    socket.write(
      '$method $path HTTP/1.1\r\nHost: localhost\r\n'
      '${headers.map((h) => '$h\r\n').join()}'
      'Content-Length: 0\r\nConnection: close\r\n\r\n',
    );
    var bytes = <int>[];
    await socket.listen(bytes.addAll).asFuture<void>();
    socket.destroy();

    var text = latin1.decode(bytes);
    var end = text.indexOf('\r\n\r\n');
    var status = int.parse(text.substring(0, end).split(' ')[1]);
    return (status, text.substring(end + 4));
  }

  test('an invalid Content-Type falls back to text/plain', () async {
    var (status, body) = await send('POST', '/type', ['Content-Type: foo']);
    expect(status, 200);
    expect(body, contains('text/plain'));
  });

  test('a request that cannot be handled gets a 400, and the server '
      'keeps serving', () async {
    // dart:io refuses to pick one of several values for this header.
    var (status, _) = await send('GET', '/', [
      'X-HTTP-Method-Override: POST',
      'X-HTTP-Method-Override: PUT',
    ]);
    expect(status, 400);
    expect((await send('GET', '/', [])).$1, 200);
  });

  test('handleRequest on a user-owned server answers 400 instead of '
      'throwing', () async {
    var server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(() => server.close(force: true));
    server.listen(http.handleRequest);

    var (status, _) = await send('GET', '/', [
      'X-HTTP-Method-Override: POST',
      'X-HTTP-Method-Override: PUT',
    ], port: server.port);
    expect(status, 400);
  });
}
