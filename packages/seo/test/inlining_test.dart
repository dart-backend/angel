import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:angel3_seo/angel3_seo.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:test/test.dart';

void main() {
  late MemoryFileSystem fs;
  late Directory web;

  setUp(() {
    fs = MemoryFileSystem();
    fs.file('/secret.txt').writeAsStringSync('SECRET');
    web = fs.directory('/srv/web')..createSync(recursive: true);
    web.childFile('site.css').writeAsStringSync('body { color: red; }');
    web.childFile('print.css').writeAsStringSync('body { color: black; }');
    web
        .childFile('app.js')
        .writeAsStringSync(
          'var end = "</script><b>not markup</b>"; var c = "<!--";',
        );
  });

  /// [page] with its assets inlined, as [inlineAssetsIntoDocument] does.
  Future<html.Document> inline(String page) async {
    var doc = html.parse(page);
    await inlineAssetsIntoDocument(doc, web);
    return doc;
  }

  group('assets', () {
    test('a leading / is the root of the asset directory', () async {
      var doc = await inline(
        '<html><head><link rel="stylesheet" href="/site.css"></head></html>',
      );
      expect(doc.querySelector('style')?.text, 'body { color: red; }');
      expect(doc.querySelector('link'), isNull);
    });

    test('out of the asset directory are not inlined', () async {
      for (var ref in [
        '../../secret.txt',
        '/../../secret.txt',
        '%2e%2e/%2e%2e/secret.txt',
        '..%5c..%5csecret.txt',
      ]) {
        var doc = await inline(
          '<html><body><script src="$ref"></script></body></html>',
        );
        expect(doc.outerHtml, isNot(contains('SECRET')), reason: ref);
        expect(doc.querySelector('script')?.attributes['src'], ref);
      }
    });

    test('of another host are not inlined', () async {
      var doc = await inline(
        '<html><head><link rel="stylesheet" href="//cdn.example/site.css">'
        '</head></html>',
      );
      expect(doc.querySelector('link'), isNotNull);
    });

    test('that are missing or malformed are left as they are', () async {
      var doc = await inline(
        '<html><head><link rel="stylesheet"><link rel="stylesheet" '
        'href="http://[::1"><script src=""></script></head></html>',
      );
      expect(doc.getElementsByTagName('link'), hasLength(2));
    });
  });

  group('inlined', () {
    test('a script cannot end its element early', () async {
      var doc = await inline(
        '<html><body><script src="app.js"></script></body></html>',
      );
      // Parsed again, as a browser would.
      var reparsed = html.parse(doc.outerHtml);
      var scripts = reparsed.getElementsByTagName('script');
      expect(scripts, hasLength(1));
      expect(scripts.single.text, contains(r'<\/script>'));
      expect(reparsed.querySelector('b'), isNull);
    });

    test('a stylesheet keeps its media', () async {
      var doc = await inline(
        '<html><head><link rel="stylesheet" media="print" href="print.css">'
        '</head></html>',
      );
      expect(doc.querySelector('style')?.attributes['media'], 'print');
    });

    test('a stylesheet of any case of rel, anywhere, is inlined', () async {
      var doc = await inline(
        '<html><body><link rel="Stylesheet" href="site.css"></body></html>',
      );
      expect(doc.querySelector('style'), isNotNull);
    });

    test('async and deferred scripts stay external, but modules', () async {
      var doc = await inline(
        '<html><body><script async src="app.js"></script>'
        '<script defer src="app.js"></script>'
        '<script type="module" defer src="app.js"></script></body></html>',
      );
      var scripts = doc.getElementsByTagName('script');
      expect(scripts[0].attributes['src'], 'app.js');
      expect(scripts[1].attributes['src'], 'app.js');
      expect(scripts[2].attributes.containsKey('src'), isFalse);
    });
  });

  group('inlineAssetsFromVirtualDirectory', () {
    late AngelHttp http;

    setUp(() {
      web
          .childFile('index.html')
          .writeAsStringSync(
            '<html><head><link rel="stylesheet" href="/site.css"></head>'
            '<body>é</body></html>',
          );
      var app = Angel();
      var vDir = inlineAssetsFromVirtualDirectory(
        CachingVirtualDirectory(app, fs, source: web),
      );
      app.fallback(vDir.handleRequest);
      http = AngelHttp(app);
    });

    Future<({int status, String body, String? etag})> get(
      String path, [
      Map<String, String> headers = const {},
    ]) async {
      var rq = MockHttpRequest('GET', Uri.parse(path));
      headers.forEach(rq.headers.add);
      await rq.close();
      await http.handleRequest(rq);
      var body = await rq.response.transform(utf8.decoder).join();
      return (
        status: rq.response.statusCode,
        body: body,
        etag: rq.response.headers.value('etag'),
      );
    }

    test('serves the page inlined, as UTF-8', () async {
      var got = await get('/index.html');
      expect(got.status, 200);
      expect(got.body, contains('body { color: red; }'));
      expect(got.body, contains('<meta charset="utf-8">'));
      expect(got.body, contains('é'));
    });

    test('keeps the caching of the directory it wraps', () async {
      var first = await get('/index.html');
      expect(first.etag, isNotNull);
      expect(
        (await get('/index.html', {'if-none-match': first.etag!})).status,
        304,
      );
    });

    test('changes its ETag when an asset changes', () async {
      var first = await get('/index.html');
      web.childFile('site.css')
        ..writeAsStringSync('body { color: blue; }')
        ..setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
      var got = await get('/index.html', {'if-none-match': first.etag!});
      expect(got.status, 200);
      expect(got.body, contains('color: blue'));
    });
  });
}
