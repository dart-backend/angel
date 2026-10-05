import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:file/local.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  const fs = LocalFileSystem();

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('angel_download');
    File('${tmp.path}/report.txt').writeAsStringSync('report body');
    File('${tmp.path}/data.unknownext').writeAsStringSync('data');
  });

  tearDownAll(() async {
    try {
      await tmp.delete(recursive: true);
    } on FileSystemException {
      // Windows may still hold a file open briefly.
    }
  });

  group('download', () {
    late AngelHttp http;
    late HttpClient client;

    setUp(() async {
      var app = Angel()
        ..get('/report', (req, res) {
          return res.download(fs.file('${tmp.path}/report.txt'));
        })
        ..get('/named', (req, res) {
          return res.download(
            fs.file('${tmp.path}/report.txt'),
            filename: 'Q3 "final" résumé.txt',
          );
        })
        ..get('/unknown', (req, res) {
          return res.download(fs.file('${tmp.path}/data.unknownext'));
        })
        ..get('/missing', (req, res) {
          return res.download(fs.file('${tmp.path}/nope.txt'));
        })
        ..get('/buffered', (req, res) {
          res.useBuffer();
          return res.download(fs.file('${tmp.path}/report.txt'));
        })
        // The router does not route HEAD to GET handlers, so register it.
        ..addRoute('HEAD', '/report', (req, res) {
          return res.download(fs.file('${tmp.path}/report.txt'));
        })
        ..get('/stream-missing', (req, res) {
          return res.streamFile(fs.file('${tmp.path}/nope.txt'));
        });
      http = AngelHttp(app);
      await http.startServer('127.0.0.1', 0);
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await http.close();
    });

    Future<(HttpClientResponse, String)> request(
      String path, {
      String method = 'GET',
    }) async {
      var rq = await client.openUrl(method, http.uri.replace(path: path));
      rq.headers
        ..set('accept', 'application/json')
        ..set('accept-encoding', 'identity');
      var rs = await rq.close();
      return (rs, await rs.transform(utf8.decoder).join());
    }

    test('sends the file with its base name, not its path', () async {
      var (rs, body) = await request('/report');
      expect(rs.statusCode, 200);
      expect(body, 'report body');
      expect(
        rs.headers.value('content-disposition'),
        'attachment; filename="report.txt"',
      );
      expect(rs.headers.contentType?.mimeType, 'text/plain');
      expect(rs.headers.contentLength, 'report body'.length);
    });

    test('encodes any filename safely', () async {
      var (rs, body) = await request('/named');
      expect(rs.statusCode, 200);
      expect(body, 'report body');
      var header = rs.headers.value('content-disposition')!;
      expect(header, contains('filename="Q3 _final_ r_sum_.txt"'));
      expect(
        header,
        contains("filename*=UTF-8''Q3%20%22final%22%20r%C3%A9sum%C3%A9.txt"),
      );
    });

    test('uses application/octet-stream for unknown types', () async {
      var (rs, body) = await request('/unknown');
      expect(rs.statusCode, 200);
      expect(rs.headers.contentType?.mimeType, 'application/octet-stream');
      expect(body, 'data');
    });

    test('a missing file is a 404 that does not reveal the path', () async {
      var (rs, body) = await request('/missing');
      expect(rs.statusCode, 404);
      expect(body, isNot(contains(tmp.path)));
    });

    test('HEAD sends the headers without a body', () async {
      var (rs, body) = await request('/report', method: 'HEAD');
      expect(rs.statusCode, 200);
      expect(rs.headers.contentLength, 'report body'.length);
      expect(body, isEmpty);
    });

    test('works on a buffered response', () async {
      var (rs, body) = await request('/buffered');
      expect(rs.statusCode, 200);
      expect(body, 'report body');
    });

    test('streamFile: a missing file is a 404 without the path', () async {
      var (rs, body) = await request('/stream-missing');
      expect(rs.statusCode, 404);
      expect(body, isNot(contains(tmp.path)));
    });
  });

  group('attachmentDisposition', () {
    test('quotes a plain name', () {
      expect(
        ResponseContext.attachmentDisposition('a b.pdf'),
        'attachment; filename="a b.pdf"',
      );
    });

    test('adds filename* for names that need it', () {
      expect(
        ResponseContext.attachmentDisposition("it's (1)*.txt"),
        'attachment; filename="it\'s (1)*.txt"',
      );
      expect(
        ResponseContext.attachmentDisposition('日本.txt'),
        "attachment; filename=\"__.txt\"; filename*=UTF-8''%E6%97%A5%E6%9C%AC.txt",
      );
      expect(
        ResponseContext.attachmentDisposition('a\\b.txt'),
        "attachment; filename=\"a_b.txt\"; filename*=UTF-8''a%5Cb.txt",
      );
    });

    test('the result is always a valid header value', () {
      for (var name in ['x\r\ny.txt', '"', 'é', 'tab\there']) {
        expect(
          ResponseContext.isValidHeaderValue(
            ResponseContext.attachmentDisposition(name),
          ),
          isTrue,
          reason: name,
        );
      }
    });
  });

  group('startServer', () {
    test('rethrows the original error when binding fails', () async {
      var first = AngelHttp(Angel());
      var server = await first.startServer('127.0.0.1', 0);
      var second = AngelHttp(Angel());
      try {
        await expectLater(
          second.startServer('127.0.0.1', server.port),
          throwsA(isA<SocketException>()),
        );
      } finally {
        await first.close();
      }
    });

    test('closes the server and rethrows when a startup hook fails', () async {
      var app = Angel()
        ..startupHooks.add((app) => throw StateError('hook failed'));
      var http = AngelHttp(app);
      // Find a free port to bind.
      var probe = await ServerSocket.bind('127.0.0.1', 0);
      var port = probe.port;
      await probe.close();

      await expectLater(
        http.startServer('127.0.0.1', port),
        throwsA(isA<StateError>()),
      );
      expect(http.server, isNull);

      // The port was released, so it can be bound again.
      var again = await HttpServer.bind('127.0.0.1', port);
      await again.close(force: true);
    });
  });
}
