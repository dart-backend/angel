import 'dart:async';
import 'dart:io' hide BytesBuilder;

import 'package:angel3_framework/angel3_framework.dart' hide Header;
import 'package:angel3_framework/http2.dart';
import 'package:http2/transport.dart';
import 'package:test/test.dart';

void main() {
  late AngelHttp2 http2;
  late Uri root;
  late HttpClient http1;

  /// What a streamed response's own headers and cookies held after it sent
  /// them.
  late Map<String, Object> seen;

  setUp(() async {
    var app = Angel()
      ..get('/', (req, res) => res.write('buffered'))
      ..get('/stream', (req, res) async {
        // Its own headers, as it sends them before the driver would.
        await res.addStream(Stream.value('streamed'.codeUnits));
      })
      ..get('/own', (req, res) {
        res.headers
          ..['cache-control'] = 'public'
          ..['x-frame-options'] = 'DENY';
        return 'own';
      })
      ..get('/cookie', (req, res) {
        res.cookies.add(Cookie('a', '5'));
        return 'cookie';
      })
      ..get('/inspect', (req, res) async {
        await res.addStream(Stream.value('inspected'.codeUnits));
        seen = {
          'cache-control': res.headers.containsKey('cache-control'),
          'cookies': res.cookies.length,
        };
      })
      ..get('/fail', (req, res) => throw StateError('fail'))
      ..get('/session', (req, res) {
        req.session!['seen'] = true;
        return 'session';
      });
    var ctx = SecurityContext()
      ..useCertificateChain('dev.pem')
      ..usePrivateKey('dev.key', password: 'dartdart')
      ..setAlpnProtocols(['h2', 'http/1.1'], true);
    http2 = AngelHttp2(app, ctx, allowHttp1: true)
      // Before startServer, which they also apply to.
      ..addResponseHeader({
        'cache-control': 'no-store',
        'x-list': ['a', 'b'],
        'set-cookie': ['a=1', 'b=2; Path=/x; HttpOnly'],
      })
      ..removeResponseHeader({'x-frame-options': 'sameorigin', 'x-list': 'b'});
    var server = await http2.startServer();
    root = Uri.parse('https://127.0.0.1:${server.port}');
    http1 = HttpClient()..badCertificateCallback = (_, _, _) => true;
  });

  tearDown(() async {
    http1.close(force: true);
    await http2.close();
  });

  /// The headers of an HTTP/2 GET of [path], with each value of a header
  /// that is sent several times.
  Future<Map<String, List<String>>> h2(String? path) async {
    var socket = await SecureSocket.connect(
      root.host,
      root.port,
      onBadCertificate: (_) => true,
      supportedProtocols: ['h2'],
    );
    var connection = ClientTransportConnection.viaSocket(socket);
    var stream = connection.makeRequest([
      Header.ascii(':authority', root.authority),
      Header.ascii(':method', 'GET'),
      if (path != null) Header.ascii(':path', path),
      Header.ascii(':scheme', root.scheme),
    ], endStream: true);
    var headers = <String, List<String>>{};
    await for (var message in stream.incomingMessages) {
      if (message is HeadersStreamMessage) {
        for (var header in message.headers) {
          headers
              .putIfAbsent(String.fromCharCodes(header.name), () => [])
              .add(String.fromCharCodes(header.value));
        }
      }
    }
    await connection.finish();
    return headers;
  }

  /// The headers of an HTTP/1 GET of [path], which the fallback serves.
  Future<HttpHeaders> h1(String path) async {
    var response = await (await http1.getUrl(root.replace(path: path))).close();
    await response.drain<void>();
    return response.headers;
  }

  String cookieName(String setCookie) => setCookie.split('=').first;

  group('HTTP/2 responses get the defaults', () {
    test('buffered', () async {
      var headers = await h2('/');
      expect(headers['cache-control'], ['no-store']);
      expect(headers['x-list'], ['a']);
      expect(headers, isNot(contains('x-frame-options')));
      expect(headers['set-cookie'], ['a=1', 'b=2; Path=/x; HttpOnly']);
    });

    test('streamed, which sends its own headers', () async {
      var headers = await h2('/stream');
      expect(headers['cache-control'], ['no-store']);
      expect(headers['set-cookie'], ['a=1', 'b=2; Path=/x; HttpOnly']);
    });

    test('of an error, which is not finalized', () async {
      var headers = await h2('/fail');
      expect(headers[':status'], ['500']);
      expect(headers['cache-control'], ['no-store']);
    });

    test('of a request that cannot be read', () async {
      // Without a :path, so that no context is made for it.
      var headers = await h2(null);
      expect(headers[':status']!.single, isNot('200'));
      expect(headers['cache-control'], ['no-store']);
    });

    test('which the headers of a handler replace', () async {
      var headers = await h2('/own');
      expect(headers['cache-control'], ['public']);
      expect(headers['x-frame-options'], ['DENY']);
    });

    test('with the cookies of a handler last, so that they win', () async {
      var cookies = (await h2('/cookie'))['set-cookie']!;
      expect(cookies.map(cookieName), ['a', 'b', 'a']);
      expect(cookies.last, startsWith('a=5'));
    });
  });

  group('a default that cannot be sent', () {
    test('throws, and leaves the defaults as they were', () async {
      for (var headers in <Map<String, Object?>>[
        {'bad name': 'x'},
        {'x-new': 'line\nbreak'},
        {'x-new': 'café'},
        // A valid one with a bad cookie: neither is added.
        {'x-new': 'a', 'set-cookie': 'no cookie'},
        // Values dart:io rejects for these headers.
        {'x-new': 'a', 'expires': 0},
        {'x-new': 'a', 'host': 8080},
        {'x-new': 'a', 'content-length': -1},
      ]) {
        expect(
          () => http2.addResponseHeader(headers),
          throwsArgumentError,
          reason: '$headers',
        );
      }
      expect(
        () => http2.removeResponseHeader({'bad name': null}),
        throwsArgumentError,
      );
      expect(await h2('/'), isNot(contains('x-new')));
      expect((await h1('/')).value('x-new'), isNull);
    });

    test('before startServer does not keep it from starting', () async {
      await http2.close();
      var ctx = SecurityContext()
        ..useCertificateChain('dev.pem')
        ..usePrivateKey('dev.key', password: 'dartdart')
        ..setAlpnProtocols(['h2', 'http/1.1'], true);
      http2 = AngelHttp2(
        Angel()..get('/', (req, res) => 'ok'),
        ctx,
        allowHttp1: true,
      );
      expect(
        () => http2.addResponseHeader({'bad name': 'x'}),
        throwsArgumentError,
      );
      expect(
        () => http2.addResponseHeader({'expires': 0}),
        throwsArgumentError,
      );
      var server = await http2.startServer();
      root = Uri.parse('https://127.0.0.1:${server.port}');
      // It started, and serves the request.
      expect((await h1('/')).contentType?.mimeType, isNotNull);
    });
  });

  test('a header dart:io keeps one value of gets the last one', () async {
    http2
      ..addResponseHeader({'expires': 'Sun, 25 Oct 2026 00:00:00 GMT'})
      ..addResponseHeader({'expires': 'Mon, 26 Oct 2026 00:00:00 GMT'});
    expect((await h2('/'))['expires'], ['Mon, 26 Oct 2026 00:00:00 GMT']);
    expect((await h1('/'))['expires'], ['Mon, 26 Oct 2026 00:00:00 GMT']);
  });

  test('HTTP/2 responses do not get a default content-length', () async {
    http2.addResponseHeader({'content-length': 0});
    // Streamed, with no length of its own.
    expect(await h2('/stream'), isNot(contains('content-length')));
  });

  test('a list changed after the call changes no default', () async {
    // Before startServer, which gets the change then, after the list has
    // changed.
    await http2.close();
    var ctx = SecurityContext()
      ..useCertificateChain('dev.pem')
      ..usePrivateKey('dev.key', password: 'dartdart')
      ..setAlpnProtocols(['h2', 'http/1.1'], true);
    http2 = AngelHttp2(
      Angel()..get('/', (req, res) => 'ok'),
      ctx,
      allowHttp1: true,
    );
    var values = ['a'];
    http2.addResponseHeader({'x-changed': values});
    values.add('b\nunchecked');
    var server = await http2.startServer();
    root = Uri.parse('https://127.0.0.1:${server.port}');
    expect((await h2('/'))['x-changed'], ['a']);
    expect((await h1('/'))['x-changed'], ['a']);
  });

  test('a default cookie is sent over HTTP/2 as given', () async {
    var cookie = 'id=1; Path=/; Secure; Partitioned; Priority=High';
    http2.addResponseHeader({'set-cookie': cookie});
    expect((await h2('/'))['set-cookie'], contains(cookie));
  });

  test('a response keeps the defaults out of its own headers', () async {
    await h2('/inspect');
    expect(seen, {'cache-control': false, 'cookies': 0});
  });

  test('HTTP/2 responses do not get the headers HTTP/2 forbids', () async {
    http2.addResponseHeader({'connection': 'keep-alive', 'x-kept': 'a'});
    var headers = await h2('/');
    expect(headers, isNot(contains('connection')));
    expect(headers['x-kept'], ['a']);
  });

  test('a session cookie comes after a default one of its name', () async {
    http2.addResponseHeader({'set-cookie': 'DARTSESSID=default; Path=/'});
    var cookies = (await h2(
      '/session',
    ))['set-cookie']!.where((c) => cookieName(c) == 'DARTSESSID').toList();
    expect(cookies.first, startsWith('DARTSESSID=default'));
    expect(cookies.last, isNot(startsWith('DARTSESSID=default')));
  });

  group('HTTP/1 responses get the defaults', () {
    test('and lose those of dart:io that are removed', () async {
      var headers = await h1('/');
      expect(headers.value('cache-control'), 'no-store');
      expect(headers['x-list'], ['a']);
      expect(headers.value('x-frame-options'), isNull);
      expect(headers['set-cookie'], ['a=1', 'b=2; Path=/x; HttpOnly']);
    });

    test('which the headers of a handler replace', () async {
      var headers = await h1('/own');
      expect(headers.value('cache-control'), 'public');
      expect(headers.value('x-frame-options'), 'DENY');
    });
  });
}
