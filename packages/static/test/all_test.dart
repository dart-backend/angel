import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/local.dart';
import 'package:http/http.dart' show Client;
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  Angel app;
  late AngelHttp http;
  var testDir = const LocalFileSystem().directory('test');
  late String url;
  var client = Client();

  setUp(() async {
    app = Angel();
    http = AngelHttp(app);
    app.logger = Logger('angel')..onRecord.listen(print);

    app.fallback(
      VirtualDirectory(
        app,
        const LocalFileSystem(),
        source: testDir,
        publicPath: '/virtual',
        indexFileNames: ['index.txt'],
      ).handleRequest,
    );

    app.fallback(
      VirtualDirectory(
        app,
        const LocalFileSystem(),
        source: testDir,
        useBuffer: true,
        indexFileNames: ['index.php', 'index.txt'],
      ).handleRequest,
    );

    app.fallback((req, res) => 'Fallback');

    app.dumpTree(showMatchers: true);

    var server = await http.startServer();
    url = 'http://${server.address.host}:${server.port}';
  });

  tearDown(() async {
    if (http.server != null) await http.server!.close(force: true);
  });

  test('can serve files, with correct Content-Type', () async {
    var response = await client.get(Uri.parse('$url/sample.txt'));
    expect(response.body, equals('Hello world'));
    expect(response.headers['content-type'], contains('text/plain'));
  });

  test('can serve child directories', () async {
    var response = await client.get(Uri.parse('$url/nested'));
    expect(response.body, equals('Bird'));
    expect(response.headers['content-type'], contains('text/plain'));
  });

  test('non-existent files are skipped', () async {
    var response = await client.get(Uri.parse('$url/nonexist.ent'));
    expect(response.body, equals('"Fallback"'));
  });

  test('can match index files', () async {
    var response = await client.get(Uri.parse(url));
    expect(response.body, equals('index!'));
  });

  test('virtualRoots can match index', () async {
    var response = await client.get(Uri.parse('$url/virtual'));
    expect(response.body, equals('index!'));
  });

  test('chrome accept', () async {
    var response = await client.get(
      Uri.parse('$url/virtual'),
      headers: {
        'accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      },
    );
    expect(response.body, equals('index!'));
  });
}
