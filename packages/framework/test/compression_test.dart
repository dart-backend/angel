import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:file/local.dart';
import 'package:test/test.dart';

/// Response compression on unbuffered responses (the default), over a real
/// HTTP/1.1 server so dart:io enforces Content-Length.
void main() {
  late Angel app;
  late AngelHttp http;
  late HttpClient client;
  late Directory tmp;
  late File file;

  // Large enough to span many chunks when streamed.
  final fileText = List.generate(5000, (i) => 'line $i of the file\n').join();

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('angel_compression');
    file = File('${tmp.path}/data.txt')..writeAsStringSync(fileText);
  });

  tearDownAll(() async {
    try {
      await tmp.delete(recursive: true);
    } on FileSystemException {
      // Windows may still hold the file open briefly; leave it to the OS.
    }
  });

  setUp(() async {
    app = Angel()
      ..encoders['gzip'] = gzip.encoder
      ..encoders['deflate'] = zlib.encoder
      ..get('/file', (req, res) {
        return res.streamFile(const LocalFileSystem().file(file.path));
      })
      ..get('/writes', (req, res) async {
        res
          ..write('Hello, ')
          ..write('world')
          ..write('!');
        await res.close();
      });
    http = AngelHttp(app);
    await http.startServer('127.0.0.1', 0);
    client = HttpClient()..autoUncompress = false;
  });

  tearDown(() async {
    client.close(force: true);
    await http.close();
  });

  Future<HttpClientResponse> get(String path, String acceptEncoding) async {
    var rq = await client.getUrl(http.uri.replace(path: path));
    rq.headers.set('accept-encoding', acceptEncoding);
    return rq.close();
  }

  Future<List<int>> bytesOf(HttpClientResponse rs) =>
      rs.fold<List<int>>([], (out, chunk) => out..addAll(chunk));

  /// Counts gzip member headers (magic bytes + deflate method).
  int gzipMembers(List<int> bytes) {
    var count = 0;
    for (var i = 0; i + 2 < bytes.length; i++) {
      if (bytes[i] == 0x1f && bytes[i + 1] == 0x8b && bytes[i + 2] == 8) {
        count++;
      }
    }
    return count;
  }

  group('streamFile', () {
    test('serves a compressed file without a stale Content-Length', () async {
      var rs = await get('/file', 'gzip');
      var body = await bytesOf(rs);

      expect(rs.statusCode, 200);
      expect(rs.headers.value('content-encoding'), 'gzip');
      expect(rs.headers.value('content-length'), isNull);
      expect(utf8.decode(gzip.decode(body)), fileText);
    });

    test('keeps Content-Length when not compressing', () async {
      var rs = await get('/file', 'identity');
      var body = await bytesOf(rs);

      expect(rs.headers.value('content-encoding'), isNull);
      expect(rs.headers.contentLength, fileText.length);
      expect(utf8.decode(body), fileText);
    });

    test('the server keeps serving afterwards', () async {
      await bytesOf(await get('/file', 'gzip'));
      var rs = await get('/writes', 'identity');
      expect(utf8.decode(await bytesOf(rs)), 'Hello, world!');
    });
  });

  group('multiple writes', () {
    test('produce a single gzip stream', () async {
      var rs = await get('/writes', 'gzip');
      var body = await bytesOf(rs);

      expect(rs.headers.value('content-encoding'), 'gzip');
      expect(gzipMembers(body), 1);
      expect(utf8.decode(gzip.decode(body)), 'Hello, world!');
    });

    test('produce a single deflate stream', () async {
      var rs = await get('/writes', 'deflate');
      var body = await bytesOf(rs);

      expect(rs.headers.value('content-encoding'), 'deflate');
      expect(utf8.decode(zlib.decode(body)), 'Hello, world!');
    });
  });

  group('Accept-Encoding', () {
    test('uses the first acceptable encoding in client order', () async {
      var rs = await get('/writes', 'br, deflate, gzip');
      await bytesOf(rs);
      expect(rs.headers.value('content-encoding'), 'deflate');
    });

    test('skips encodings with q=0', () async {
      var rs = await get('/writes', 'gzip;q=0, deflate;q=0.0');
      var body = await bytesOf(rs);
      expect(rs.headers.value('content-encoding'), isNull);
      expect(utf8.decode(body), 'Hello, world!');
    });

    test('* selects an available encoder', () async {
      var rs = await get('/writes', '*');
      await bytesOf(rs);
      expect(rs.headers.value('content-encoding'), 'gzip');
    });
  });

  group('selectEncoder', () {
    var encoders = {'gzip': gzip.encoder};

    test('returns null without encoders or a header', () {
      expect(ResponseContext.selectEncoder({}, 'gzip'), isNull);
      expect(ResponseContext.selectEncoder(encoders, null), isNull);
    });

    test('ignores non-zero quality values', () {
      expect(
        ResponseContext.selectEncoder(encoders, 'gzip;q=0.5')?.name,
        'gzip',
      );
    });
  });
}
