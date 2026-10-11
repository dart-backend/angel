import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart' hide Header;
import 'package:angel3_framework/http2.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:http/src/multipart_file.dart' as http;
import 'package:http/src/multipart_request.dart' as http;
import 'package:http/io_client.dart';
import 'package:http2/transport.dart';
import 'package:file/local.dart';
import 'package:http_parser/http_parser.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'http2_client.dart';

const String jfk =
    'Ask not what your country can do for you, but what you can do for your country.';

Stream<List<int>> jfkStream() {
  return Stream.fromIterable([utf8.encode(jfk)]);
}

void main() {
  var client = Http2Client();
  late IOClient h1c;
  Angel app;
  late AngelHttp2 http2;
  late Uri serverRoot;

  setUp(() async {
    app = Angel(reflector: MirrorsReflector())..encoders['gzip'] = gzip.encoder;
    hierarchicalLoggingEnabled = true;
    app.logger = Logger.detached('angel.http2')
      ..onRecord.listen((rec) {
        print(rec);
        if (rec.error == null) return;
        print(rec.error);
        if (rec.stackTrace != null) print(rec.stackTrace);
      });

    app.get('/', (req, res) async {
      res.write('Hello world');
      await res.close();
    });

    app.all('/method', (req, res) => req.method);

    app.get('/json', (_, _) => {'foo': 'bar'});

    app.get('/stream', (req, res) => jfkStream().pipe(res));

    app.get('/headers', (req, res) async {
      res.headers.addAll({'foo': 'bar', 'x-angel': 'http2'});
      await res.close();
    });

    app.get('/status', (req, res) async {
      res.statusCode = 1337;
      await res.close();
    });

    app.post('/body', (req, res) => req.parseBody().then((_) => req.bodyAsMap));

    app.post('/upload', (req, res) async {
      await req.parseBody();
      var body = req.bodyAsMap;
      var files = req.uploadedFiles ?? [];

      var file = files.firstWhereOrNull((f) => f.name == 'file')!;
      return [
        await file.data.map((l) => l.length).reduce((a, b) => a + b),
        file.contentType.mimeType,
        body,
      ];
    });

    app.get('/push', (req, res) async {
      res.write('ok');

      if (res is Http2ResponseContext && res.canPush) {
        var a = res.push('a')..write('a');
        await a.close();

        var b = res.push('b')..write('b');
        await b.close();
      }

      await res.close();
    });

    app.get('/buffered', (req, res) {
      res
        ..useBuffer()
        ..statusCode = 201
        ..headers['X-Mixed-Case'] = 'yes'
        ..cookies.add(Cookie('a', 'b'))
        ..write('buffered body');
      return res.close();
    });

    app.post('/trailers', (req, res) async {
      await req.parseBody();
      return {'path': req.path, 'trailer': req.headers!.value('x-trailer')};
    });

    app.post('/slow-body', (req, res) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      var length = 0;
      await req.body!.forEach((chunk) => length += chunk.length);
      return length;
    });

    app.post('/ignore-body', (req, res) => 'ignored');

    app.get('/buffered-session', (req, res) {
      res
        ..useBuffer()
        ..write(req.session!.id);
      return res.close();
    });

    app.get('/param/:name', (req, res) => req.params);

    app.get('/query', (req, res) {
      print('incoming URI: ${req.uri}');
      return req.queryParameters;
    });

    app.get('/echo-header', (req, res) => req.headers!.value('x-test'));

    app.get('/hostname', (req, res) => req.hostname);

    app.get('/session', (req, res) => req.session!.id);

    app.get('/bad-header', (req, res) {
      res.headers['x-name'] = 'café';
      return 'body';
    });

    app.get('/writes', (req, res) async {
      res
        ..write('Hello, ')
        ..write('world!');
      await res.close();
    });

    app.get(
      '/file',
      (req, res) =>
          res.streamFile(const LocalFileSystem().file('pubspec.yaml')),
    );

    var ctx = SecurityContext()
      ..useCertificateChain('dev.pem')
      ..usePrivateKey('dev.key', password: 'dartdart')
      ..setAlpnProtocols(['h2'], true);

    // Create an HTTP client that trusts our server.
    h1c = IOClient(HttpClient()..badCertificateCallback = (_, _, _) => true);

    http2 = AngelHttp2(app, ctx, allowHttp1: true);

    var server = await http2.startServer();
    serverRoot = Uri.parse('https://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    await http2.close();
    h1c.close();
  });

  test('buffered response', () async {
    var response = await client.get(serverRoot);
    expect(response.body, 'Hello world');
  });

  /// Sends a GET and returns every message of the response, so tests can
  /// check how it is framed (Http2Client merges all HEADERS frames).
  Future<List<StreamMessage>> rawGet(String path) async {
    var socket = await SecureSocket.connect(
      serverRoot.host,
      serverRoot.port,
      onBadCertificate: (_) => true,
      supportedProtocols: ['h2'],
    );
    var connection = ClientTransportConnection.viaSocket(socket);
    var stream = connection.makeRequest([
      Header.ascii(':authority', serverRoot.authority),
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', path),
      Header.ascii(':scheme', serverRoot.scheme),
    ], endStream: true);
    // Fails if the server resets the stream instead of ending it.
    var messages = await stream.incomingMessages.toList();
    await connection.finish();
    return messages;
  }

  /// Sends [headers] (and [body], then [trailers], if given) on a new
  /// connection, and returns the response's status and body.
  Future<(String?, String)> rawRequest(
    List<Header> headers, {
    List<int>? body,
    List<Header>? trailers,
  }) async {
    var socket = await SecureSocket.connect(
      serverRoot.host,
      serverRoot.port,
      onBadCertificate: (_) => true,
      supportedProtocols: ['h2'],
    );
    var connection = ClientTransportConnection.viaSocket(socket);
    var stream = connection.makeRequest(
      headers,
      endStream: body == null && trailers == null,
    );
    if (body != null) stream.sendData(body, endStream: trailers == null);
    if (trailers != null) stream.sendHeaders(trailers, endStream: true);

    String? status;
    var out = BytesBuilder();
    await for (var msg in stream.incomingMessages) {
      if (msg is HeadersStreamMessage) {
        for (var h in msg.headers) {
          if (ascii.decode(h.name) == ':status') status = ascii.decode(h.value);
        }
      } else if (msg is DataStreamMessage) {
        out.add(msg.bytes);
      }
    }
    await connection.finish();
    return (status, utf8.decode(out.takeBytes()));
  }

  List<Header> requestHeaders(String method, String path) => [
    Header.ascii(':authority', serverRoot.authority),
    Header.ascii(':method', method),
    Header.ascii(':path', path),
    Header.ascii(':scheme', serverRoot.scheme),
  ];

  test('trailers do not change the request', () async {
    var (status, body) = await rawRequest(
      [
        ...requestHeaders('POST', '/trailers'),
        Header.ascii('content-type', 'application/json'),
      ],
      body: utf8.encode('{}'),
      trailers: [
        Header.ascii(':path', '/elsewhere'),
        Header.ascii('x-trailer', 'yes'),
      ],
    );
    expect(status, '200');
    expect(json.decode(body), {'path': 'trailers', 'trailer': null});
  });

  test('a request without :path is a 400', () async {
    var (status, _) = await rawRequest([
      Header.ascii(':authority', serverRoot.authority),
      Header.ascii(':method', 'GET'),
      Header.ascii(':scheme', serverRoot.scheme),
    ]);
    expect(status, '400');
  });

  test('a malformed content-length is a 400', () async {
    var (status, _) = await rawRequest([
      ...requestHeaders('POST', '/trailers'),
      Header.ascii('content-length', 'abc'),
    ], body: utf8.encode('{}'));
    expect(status, '400');
  });

  group('request bodies', () {
    final big = List<int>.filled(1024 * 1024, 120);

    test('are complete when read late', () async {
      var (status, body) = await rawRequest(
        requestHeaders('POST', '/slow-body'),
        body: big,
      );
      expect(status, '200');
      expect(body, '${big.length}');
    });

    test('do not stop a handler that ignores them', () async {
      var (status, body) = await rawRequest(
        requestHeaders('POST', '/ignore-body'),
        body: big,
      );
      expect(status, '200');
      expect(body, '"ignored"');
    });
  });

  test('app.serializer is used', () async {
    var custom = Angel()
      ..serializer = ((_) => 'custom')
      ..get('/', (req, res) => {'a': 1});
    var ctx = SecurityContext()
      ..useCertificateChain('dev.pem')
      ..usePrivateKey('dev.key', password: 'dartdart')
      ..setAlpnProtocols(['h2'], true);
    var h2 = AngelHttp2(custom, ctx);
    var server = await h2.startServer();
    addTearDown(h2.close);
    var response = await client.get(
      Uri.parse('https://127.0.0.1:${server.port}/'),
    );
    expect(response.body, 'custom');
  });

  test('close closes services once, with allowHttp1', () async {
    var closes = 0;
    var closing = Angel()..use('/s', _CountingService(() => closes++));
    var ctx = SecurityContext()
      ..useCertificateChain('dev.pem')
      ..usePrivateKey('dev.key', password: 'dartdart')
      ..setAlpnProtocols(['h2', 'http/1.1'], true);
    var h2 = AngelHttp2(closing, ctx, allowHttp1: true);
    await h2.startServer();
    await h2.close();
    expect(closes, 1);
  });

  group('res.useBuffer()', () {
    test('sends one HEADERS frame, starting with :status', () async {
      var messages = await rawGet('/buffered');
      var frames = messages.whereType<HeadersStreamMessage>().toList();
      expect(frames, hasLength(1));
      var names = [for (var h in frames.single.headers) ascii.decode(h.name)];
      expect(names.first, ':status');
      expect(
        names,
        everyElement(predicate<String>((n) => n == n.toLowerCase())),
      );
      expect(names.where((n) => n == 'content-length'), hasLength(1));
    });

    test('sends status, headers, cookies and body', () async {
      var response = await client.get(serverRoot.replace(path: '/buffered'));
      expect(response.statusCode, 201);
      expect(response.headers['x-mixed-case'], 'yes');
      expect(response.headers['set-cookie'], startsWith('a=b'));
      expect(response.headers['content-length'], '13');
      expect(response.body, 'buffered body');
    });

    test('compresses the body', () async {
      var response = await client.get(
        serverRoot.replace(path: '/buffered'),
        headers: {'accept-encoding': 'gzip'},
      );
      expect(response.headers['content-encoding'], 'gzip');
      expect(
        response.headers['content-length'],
        response.bodyBytes.length.toString(),
      );
      expect(utf8.decode(gzip.decode(response.bodyBytes)), 'buffered body');
    });

    test('sets the session cookie', () async {
      var response = await client.get(
        serverRoot.replace(path: '/buffered-session'),
      );
      expect(
        response.headers['set-cookie'],
        'DARTSESSID=${response.body}; Secure; HttpOnly',
      );
    });
  });

  group('headers', () {
    // A bare '%' used to throw outside the error zone and kill the server.
    for (var value in ['100%', 'a%20b', 'x, y', '%zz']) {
      test('passes "$value" through unchanged', () async {
        var response = await client.get(
          serverRoot.replace(path: '/echo-header'),
          headers: {'x-test': value},
        );
        expect(response.statusCode, 200);
        expect(response.body, json.encode(value));
      });
    }

    test('server keeps serving after a malformed header', () async {
      await client.get(
        serverRoot.replace(path: '/echo-header'),
        headers: {'x-test': '100%'},
      );
      var response = await client.get(serverRoot);
      expect(response.body, 'Hello world');
    });

    test('hostname comes from :authority', () async {
      var response = await client.get(serverRoot.replace(path: '/hostname'));
      expect(json.decode(response.body), serverRoot.authority);
    });
  });

  group('sessions', () {
    Future<String> sessionId({String? cookie}) async {
      var response = await client.get(
        serverRoot.replace(path: '/session'),
        headers: {'cookie': ?cookie},
      );
      return json.decode(response.body) as String;
    }

    test('are reused when the client sends DARTSESSID', () async {
      var first = await sessionId();
      var second = await sessionId(cookie: 'DARTSESSID=$first');
      expect(second, first);
    });

    test('are not created for requests that do not use them', () async {
      var response = await client.get(serverRoot);
      expect(response.headers['set-cookie'], isNull);
    });

    test('do not adopt an unknown client-chosen id', () async {
      var id = await sessionId(cookie: 'DARTSESSID=attacker-chosen');
      expect(id, isNot('attacker-chosen'));
    });

    test('expire after sessionTimeout', () async {
      var shortApp = Angel()..get('/session', (req, res) => req.session!.id);
      var ctx = SecurityContext()
        ..useCertificateChain('dev.pem')
        ..usePrivateKey('dev.key', password: 'dartdart')
        ..setAlpnProtocols(['h2'], true);
      var shortLived = AngelHttp2(
        shortApp,
        ctx,
        sessionTimeout: const Duration(milliseconds: 100),
      );
      var server = await shortLived.startServer();
      var url = Uri.parse('https://127.0.0.1:${server.port}/session');

      Future<String> get({String? cookie}) async => json.decode(
        (await client.get(url, headers: {'cookie': ?cookie})).body,
      ) as String;

      var first = await get();
      expect(await get(cookie: 'DARTSESSID=$first'), first);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(await get(cookie: 'DARTSESSID=$first'), isNot(first));

      await shortLived.close();
    });
  });

  group('HEAD', () {
    for (var encoding in ['identity', 'gzip']) {
      test(
        'is answered by the GET handler without a body ($encoding)',
        () async {
          var response = await client.head(
            serverRoot,
            headers: {'accept-encoding': encoding},
          );
          expect(response.statusCode, 200);
          expect(response.bodyBytes, isEmpty);
        },
      );
    }

    test('still 404s when no GET route matches', () async {
      var response = await client.head(serverRoot.replace(path: '/nowhere'));
      expect(response.statusCode, 404);
    });
  });

  test('an invalid response header fails with a 500', () async {
    var response = await client.get(
      serverRoot.replace(path: '/bad-header'),
      headers: {'accept': 'application/json'},
    );
    expect(response.statusCode, 500);
    expect(
      json.decode(response.body)['message'],
      contains('Invalid response header'),
    );
  });

  test('the session cookie is Secure and HttpOnly', () async {
    var response = await client.get(serverRoot.replace(path: '/session'));
    var cookie = response.headers['set-cookie']!;
    expect(cookie, startsWith('DARTSESSID='));
    expect(cookie, contains('Secure'));
    expect(cookie, contains('HttpOnly'));
  });

  test('response finalizers run on unbuffered responses', () async {
    var finalized = Angel()
      ..get('/', (req, res) async {
        res
          ..write('a')
          ..write('b');
        await res.close();
      })
      ..responseFinalizers.add((req, res) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        res.headers['x-finalized'] = 'yes';
      });
    var ctx = SecurityContext()
      ..useCertificateChain('dev.pem')
      ..usePrivateKey('dev.key', password: 'dartdart')
      ..setAlpnProtocols(['h2'], true);
    var h2 = AngelHttp2(finalized, ctx);
    var server = await h2.startServer();

    var response = await client.get(
      Uri.parse('https://127.0.0.1:${server.port}/'),
    );
    expect(response.headers['x-finalized'], 'yes');
    expect(response.body, 'ab');

    await h2.close();
  });

  test('close without allowHttp1', () async {
    var ctx = SecurityContext()
      ..useCertificateChain('dev.pem')
      ..usePrivateKey('dev.key', password: 'dartdart')
      ..setAlpnProtocols(['h2'], true);
    var h2Only = AngelHttp2(Angel(), ctx);
    await h2Only.startServer();
    await expectLater(h2Only.close(), completes);
  });

  test('without allowHttp1, HTTP/1 connections are closed, not left '
      'hanging', () async {
    var ctx = SecurityContext()
      ..useCertificateChain('dev.pem')
      ..usePrivateKey('dev.key', password: 'dartdart')
      ..setAlpnProtocols(['h2', 'http/1.1'], true);
    var h2Only = AngelHttp2(Angel(), ctx);
    addTearDown(h2Only.close);
    var server = await h2Only.startServer();

    var socket = await SecureSocket.connect(
      '127.0.0.1',
      server.port,
      onBadCertificate: (_) => true,
      supportedProtocols: ['http/1.1'],
    );
    socket.write('GET / HTTP/1.1\r\nHost: localhost\r\n\r\n');
    await expectLater(
      socket.drain<void>().timeout(const Duration(seconds: 5)),
      completes,
    );
    socket.destroy();
  });

  test('allowHttp1', () async {
    var response = await h1c.get(serverRoot);
    expect(response.body, 'Hello world');
  });

  test('streamed response', () async {
    var response = await client.get(serverRoot.replace(path: '/stream'));
    expect(response.body, jfk);
  });

  group('gzip', () {
    test('buffered response', () async {
      var response = await client.get(
        serverRoot,
        headers: {'accept-encoding': 'gzip, deflate, br'},
      );
      expect(response.headers['content-encoding'], 'gzip');
      var decoded = gzip.decode(response.bodyBytes);
      expect(utf8.decode(decoded), 'Hello world');
    });

    test('streamed response', () async {
      var response = await client.get(
        serverRoot.replace(path: '/stream'),
        headers: {'accept-encoding': 'gzip'},
      );
      expect(response.headers['content-encoding'], 'gzip');
      //print(response.body);
      var decoded = gzip.decode(response.bodyBytes);
      expect(utf8.decode(decoded), jfk);
    });

    test('multiple writes produce one gzip stream', () async {
      var response = await client.get(
        serverRoot.replace(path: '/writes'),
        headers: {'accept-encoding': 'gzip'},
      );
      expect(response.headers['content-encoding'], 'gzip');
      var bytes = response.bodyBytes;
      var members = 0;
      for (var i = 0; i + 2 < bytes.length; i++) {
        if (bytes[i] == 0x1f && bytes[i + 1] == 0x8b && bytes[i + 2] == 8) {
          members++;
        }
      }
      expect(members, 1);
      expect(utf8.decode(gzip.decode(bytes)), 'Hello, world!');
    });

    test('streamFile sends no stale Content-Length', () async {
      var response = await client.get(
        serverRoot.replace(path: '/file'),
        headers: {'accept-encoding': 'gzip'},
      );
      expect(response.headers['content-encoding'], 'gzip');
      expect(response.headers['content-length'], isNull);
      expect(
        utf8.decode(gzip.decode(response.bodyBytes)),
        File('pubspec.yaml').readAsStringSync(),
      );
    });
  });

  test('query uri decoded', () async {
    var uri = serverRoot.replace(
      path: '/query',
      queryParameters: {'foo!': 'bar?'},
    );
    var response = await client.get(uri);
    print('Sent $uri');
    expect(response.body, json.encode({'foo!': 'bar?'}));
  });

  test('params uri decoded', () async {
    var response = await client.get(serverRoot.replace(path: '/param/foo!'));
    expect(response.body, json.encode({'name': 'foo!'}));
  });

  test('method parsed', () async {
    var response = await client.delete(serverRoot.replace(path: '/method'));
    expect(response.body, json.encode('DELETE'));
  });

  test('json response', () async {
    var response = await client.get(serverRoot.replace(path: '/json'));
    expect(response.body, json.encode({'foo': 'bar'}));
    expect(
      ContentType.parse(response.headers['content-type']!).mimeType,
      ContentType.json.mimeType,
    );
  });

  test('status sent', () async {
    var response = await client.get(serverRoot.replace(path: '/status'));
    expect(response.statusCode, 1337);
  });

  test('headers sent', () async {
    var response = await client.get(serverRoot.replace(path: '/headers'));
    expect(response.headers['foo'], 'bar');
    expect(response.headers['x-angel'], 'http2');
  });

  test('server push', () async {
    var socket = await SecureSocket.connect(
      serverRoot.host,
      serverRoot.port,
      onBadCertificate: (_) => true,
      supportedProtocols: ['h2'],
    );

    var connection = ClientTransportConnection.viaSocket(
      socket,
      settings: ClientSettings(allowServerPushes: true),
    );

    var headers = <Header>[
      Header.ascii(':authority', serverRoot.authority),
      Header.ascii(':method', 'GET'),
      Header.ascii(':path', serverRoot.replace(path: '/push').path),
      Header.ascii(':scheme', serverRoot.scheme),
    ];

    var stream = connection.makeRequest(headers, endStream: true);

    var bb = await stream.incomingMessages
        .where((s) => s is DataStreamMessage)
        .cast<DataStreamMessage>()
        .fold<BytesBuilder>(BytesBuilder(), (out, msg) => out..add(msg.bytes));

    // Check that main body was sent
    expect(utf8.decode(bb.takeBytes()), 'ok');

    var pushes = await stream.peerPushes.toList();
    expect(pushes, hasLength(2));

    var pushA = pushes[0], pushB = pushes[1];

    String getPath(TransportStreamPush p) => ascii.decode(
      p.requestHeaders.firstWhere((h) => ascii.decode(h.name) == ':path').value,
    );

    Future<(String?, String)> getResponse(TransportStreamPush p) async {
      String? status;
      var body = BytesBuilder();
      await for (var msg in p.stream.incomingMessages) {
        if (msg is HeadersStreamMessage) {
          for (var h in msg.headers) {
            if (ascii.decode(h.name) == ':status') {
              status = ascii.decode(h.value);
            }
          }
        } else if (msg is DataStreamMessage) {
          body.add(msg.bytes);
        }
      }
      return (status, utf8.decode(body.takeBytes()));
    }

    expect(getPath(pushA), '/a');
    expect(getPath(pushB), '/b');
    expect(await getResponse(pushA), ('200', 'a'));
    expect(await getResponse(pushB), ('200', 'b'));
  });

  group('body parsing', () {
    test('urlencoded body parsed', () async {
      var response = await client.post(
        serverRoot.replace(path: '/body'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: 'foo=bar',
      );
      expect(response.body, json.encode({'foo': 'bar'}));
    });

    test('json body parsed', () async {
      var response = await client.post(
        serverRoot.replace(path: '/body'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
        },
        body: json.encode({'foo': 'bar'}),
      );
      expect(response.body, json.encode({'foo': 'bar'}));
    });

    test('multipart body parsed', () async {
      var rq = http.MultipartRequest(
        'POST',
        serverRoot.replace(path: '/upload'),
      );
      rq.headers.addAll({'accept': 'application/json'});

      rq.fields['foo'] = 'bar';
      rq.files.add(
        http.MultipartFile(
          'file',
          Stream.fromIterable([utf8.encode('hello world')]),
          11,
          contentType: MediaType('angel', 'framework'),
        ),
      );

      var response = await client.send(rq);
      var responseBody = await response.stream.transform(utf8.decoder).join();

      expect(
        responseBody,
        json.encode([
          11,
          'angel/framework',
          {'foo': 'bar'},
        ]),
      );
    });
  });
}

class _CountingService extends Service {
  final void Function() onClose;
  _CountingService(this.onClose);

  @override
  Future<void> close() async => onClose();
}
