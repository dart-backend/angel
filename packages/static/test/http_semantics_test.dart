import 'dart:convert';
import 'dart:io' as io;

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

/// A response to a test request.
typedef Got = ({int status, String body, Map<String, String?> headers});

/// Serves [source] of [fileSystem] with [create], and requests from it.
class Site {
  final AngelHttp http;

  Site(
    FileSystem fileSystem,
    Directory source,
    VirtualDirectory Function(Angel app, FileSystem fs, Directory source)
    create, {
    List<String> encoders = const [],
  }) : http = AngelHttp(Angel()) {
    var app = http.app;
    if (encoders.contains('gzip')) app.encoders['gzip'] = io.gzip.encoder;
    app.fallback(create(app, fileSystem, source).handleRequest);
    app.fallback((req, res) => throw AngelHttpException.notFound());
  }

  Future<Got> get(String path, [Map<String, String> headers = const {}]) async {
    var rq = MockHttpRequest('GET', Uri.parse(path));
    headers.forEach(rq.headers.add);
    await rq.close();
    await http.handleRequest(rq);
    var rs = rq.response;
    var bytes = await rs.fold<List<int>>([], (a, b) => a..addAll(b));
    return (
      status: rs.statusCode,
      body: latin1.decode(bytes),
      headers: {
        for (var name in [
          'etag',
          'last-modified',
          'content-range',
          'content-length',
          'content-encoding',
          'cache-control',
        ])
          name: rs.headers.value(name),
      },
    );
  }
}

void main() {
  const local = LocalFileSystem();
  late Directory tmp, root;

  setUp(() {
    tmp = local.directory(
      io.Directory.systemTemp.createTempSync('angel3_static').path,
    );
    root = tmp.childDirectory('root')..createSync();
    tmp.childFile('secret.txt').writeAsStringSync('SECRET');
    root.childFile('a.txt').writeAsStringSync('0123456789');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Site plain({List<String> encoders = const []}) => Site(
    local,
    root,
    (app, fs, source) =>
        VirtualDirectory(app, fs, source: source, allowDirectoryListing: true),
    encoders: encoders,
  );

  Site caching() => Site(
    local,
    root,
    (app, fs, source) => CachingVirtualDirectory(app, fs, source: source),
  );

  group('ranges', () {
    test('a suffix range is the last bytes', () async {
      var got = await plain().get('/a.txt', {'range': 'bytes=-3'});
      expect(got.status, 206);
      expect(got.body, '789');
      expect(got.headers['content-range'], 'bytes 7-9/10');
    });

    test('a suffix longer than the file is the file', () async {
      var got = await plain().get('/a.txt', {'range': 'bytes=-50'});
      expect((got.status, got.body), (206, '0123456789'));
    });

    test('an end past the file is its end', () async {
      var got = await plain().get('/a.txt', {'range': 'bytes=5-100'});
      expect((got.status, got.body), (206, '56789'));
      expect(got.headers['content-range'], 'bytes 5-9/10');
      expect(got.headers['content-length'], '5');
    });

    test('a start past the file is unsatisfiable', () async {
      var got = await plain().get('/a.txt', {'range': 'bytes=10-'});
      expect(got.status, 416);
      expect(got.headers['content-range'], 'bytes */10');
    });

    test('overlapping ranges are merged', () async {
      var got = await plain().get('/a.txt', {'range': 'bytes=0-3,2-5'});
      expect((got.status, got.body), (206, '012345'));
    });

    test('a range is not encoded', () async {
      var got = await plain(encoders: ['gzip'])
          .get('/a.txt', {'range': 'bytes=2-4', 'accept-encoding': 'gzip'});
      expect((got.status, got.body), (206, '234'));
      expect(got.headers['content-encoding'], isNull);
    });
  });

  group('caching', () {
    test('an old ETag of a changed file is not a 304', () async {
      var site = caching();
      var first = await site.get('/a.txt');
      root.childFile('a.txt')
        ..writeAsStringSync('changed!')
        ..setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
      var got = await site.get('/a.txt', {
        'if-none-match': first.headers['etag']!,
      });
      expect((got.status, got.body), (200, 'changed!'));
      expect(got.headers['etag'], isNot(first.headers['etag']));
    });

    test('the ETag of the file as it is is a 304, and is quoted', () async {
      var site = caching();
      var first = await site.get('/a.txt');
      expect(first.headers['etag'], matches(RegExp(r'^".+"$')));
      var got = await site.get('/a.txt', {
        'if-none-match': 'W/"other", ${first.headers['etag']}',
      });
      expect(got.status, 304);
    });

    test('If-Modified-Since of its own Last-Modified is a 304', () async {
      root
          .childFile('a.txt')
          .setLastModifiedSync(DateTime.utc(2020, 1, 1, 10, 0, 0, 500));
      var site = caching();
      var first = await site.get('/a.txt');
      var got = await site.get('/a.txt', {
        'if-modified-since': first.headers['last-modified']!,
      });
      expect(got.status, 304);
    });

    test('If-None-Match comes before If-Modified-Since', () async {
      var got = await caching().get('/a.txt', {
        'if-none-match': '"stale"',
        'if-modified-since': io.HttpDate.format(
          DateTime.now().add(const Duration(days: 1)),
        ),
      });
      expect(got.status, 200);
    });

    test('an If-Range of a changed file sends it whole', () async {
      var site = caching();
      var first = await site.get('/a.txt');
      root.childFile('a.txt')
        ..writeAsStringSync('changed!')
        ..setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
      var got = await site.get('/a.txt', {
        'range': 'bytes=0-2',
        'if-range': first.headers['etag']!,
      });
      expect((got.status, got.body), (200, 'changed!'));
    });

    test('an If-Range of the file as it is sends the range', () async {
      var site = caching();
      var first = await site.get('/a.txt');
      var got = await site.get('/a.txt', {
        'range': 'bytes=0-2',
        'if-range': first.headers['etag']!,
      });
      expect((got.status, got.body), (206, '012'));
    });

    test('an index file is served with its own Last-Modified', () async {
      var docs = root.childDirectory('docs')..createSync();
      var index = docs.childFile('index.html')..writeAsStringSync('hi');
      index.setLastModifiedSync(DateTime.utc(2001, 2, 3, 4, 5, 6));
      var got = await caching().get('/docs/');
      expect(got.headers['last-modified'], 'Sat, 03 Feb 2001 04:05:06 GMT');
    });
  });

  group('requests', () {
    test('Accept of a wildcard type is honored', () async {
      var got = await plain().get('/a.txt', {'accept': 'text/*'});
      expect(got.status, 200);
      got = await plain().get('/a.txt', {'accept': 'image/png'});
      expect(got.status, 406);
    });

    test('a path with an encoded backslash is not found', () async {
      for (var path in ['/..%5csecret.txt', '/a%5c..%5c..%5csecret.txt']) {
        var got = await plain().get(path);
        expect(got.status, 404, reason: path);
      }
    });

    test('a public path is matched by whole segments', () async {
      root.childDirectory('foo').createSync();
      root.childFile('foo/x.txt').writeAsStringSync('x');
      var site = Site(
        local,
        root,
        (app, fs, source) =>
            VirtualDirectory(app, fs, source: source, publicPath: '/static'),
      );
      expect((await site.get('/static/foo/x.txt')).status, 200);
      expect((await site.get('/staticfoo/x.txt')).status, 404);
    });

    test('a directory listing escapes the names of its entries', () async {
      // A name that holds markup, which Windows does not allow in files.
      var fs = MemoryFileSystem();
      var source = fs.directory('/root')..createSync();
      source.childFile('<img src=x onerror=alert(1)>.txt').createSync();
      var site = Site(
        fs,
        source,
        (app, fs, source) => VirtualDirectory(
          app,
          fs,
          source: source,
          allowDirectoryListing: true,
        ),
      );
      var got = await site.get('/');
      expect(got.body, isNot(contains('<img')));
      expect(got.body, contains('&lt;img src=x onerror=alert(1)&gt;.txt'));
      expect(got.body, contains('<ul>'));
    });
  });

  group('symbolic links', () {
    late MemoryFileSystem fs;
    late Directory source;

    setUp(() {
      fs = MemoryFileSystem();
      source = fs.directory('/root')..createSync();
      fs.file('/secret.txt').writeAsStringSync('SECRET');
      source.childFile('inside.txt').writeAsStringSync('INSIDE');
      source.childLink('out.txt').createSync('/secret.txt');
      source.childLink('in.txt').createSync('/root/inside.txt');
    });

    Site site({bool follow = false}) => Site(
      fs,
      source,
      (app, fs, source) => VirtualDirectory(
        app,
        fs,
        source: source,
        followLinksOutsideSource: follow,
      ),
    );

    test('to outside the source are not served', () async {
      expect((await site().get('/out.txt')).status, 404);
    });

    test('in the source are served', () async {
      var got = await site().get('/in.txt');
      expect((got.status, got.body), (200, 'INSIDE'));
    });

    test('to outside are served with followLinksOutsideSource', () async {
      var got = await site(follow: true).get('/out.txt');
      expect((got.status, got.body), (200, 'SECRET'));
    });
  });
}
