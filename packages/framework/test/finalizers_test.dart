import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:file/local.dart';
import 'package:test/test.dart';

/// Response finalizers, over a real HTTP/1.1 server (where headers cannot
/// change once sent).
void main() {
  late Angel app;
  late AngelHttp http;
  late HttpClient client;
  late int runs;

  setUp(() async {
    runs = 0;
    app = Angel()
      ..get('/value', (req, res) => {'ok': true})
      ..get('/writes', (req, res) async {
        res
          ..write('a')
          ..write('b')
          ..write('c');
        await res.close();
      })
      ..get('/file', (req, res) {
        return res.streamFile(const LocalFileSystem().file('pubspec.yaml'));
      })
      ..get('/empty', (req, res) => res.close())
      ..get('/buffered', (req, res) {
        res
          ..useBuffer()
          ..write('original');
      });
    http = AngelHttp(app);
    await http.startServer('127.0.0.1', 0);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await http.close();
  });

  Future<(HttpClientResponse, String)> get(String path) async {
    var rq = await client.getUrl(http.uri.replace(path: path));
    rq.headers.set('accept', 'application/json');
    var rs = await rq.close();
    return (rs, await rs.transform(utf8.decoder).join());
  }

  void addHeaderFinalizer() {
    app.responseFinalizers.add((req, res) {
      runs++;
      res.headers['x-finalized'] = 'yes';
      return true;
    });
  }

  group('unbuffered responses', () {
    for (var path in ['/value', '/writes', '/file', '/empty']) {
      test('run finalizers before headers on $path', () async {
        addHeaderFinalizer();
        var (rs, _) = await get(path);
        expect(rs.statusCode, 200);
        expect(rs.headers.value('x-finalized'), 'yes');
        expect(runs, 1);
      });
    }

    test('keep the body intact', () async {
      addHeaderFinalizer();
      var (_, body) = await get('/value');
      expect(json.decode(body), {'ok': true});
    });

    test('send writes made during an async finalizer, in order', () async {
      app.responseFinalizers.add((req, res) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        res.headers['x-finalized'] = 'late';
      });
      var (rs, body) = await get('/writes');
      expect(rs.headers.value('x-finalized'), 'late');
      expect(body, 'abc');
    });

    test('let finalizers change the status code', () async {
      app.responseFinalizers.add((req, res) => res.statusCode = 202);
      var (rs, _) = await get('/value');
      expect(rs.statusCode, 202);
    });

    test('see no body (isBuffered is false)', () async {
      bool? buffered;
      app.responseFinalizers.add((req, res) => buffered = res.isBuffered);
      await get('/value');
      expect(buffered, isFalse);
    });

    test('a throwing finalizer yields an error response', () async {
      app.responseFinalizers.add(
        (req, res) => throw AngelHttpException.forbidden(),
      );
      var (rs, body) = await get('/value');
      expect(rs.statusCode, 403);
      expect(json.decode(body)['status_code'], 403);
    });
  });

  group('buffered responses', () {
    test('run finalizers once, with the full body', () async {
      String? seen;
      app.responseFinalizers.add((req, res) {
        runs++;
        seen = utf8.decode(res.buffer!.toBytes());
      });
      await get('/buffered');
      expect(seen, 'original');
      expect(runs, 1);
    });

    test('can rewrite the body', () async {
      app.responseFinalizers.add((req, res) {
        res.buffer!
          ..clear()
          ..add(utf8.encode('rewritten'));
      });
      var (_, body) = await get('/buffered');
      expect(body, 'rewritten');
    });
  });
}
