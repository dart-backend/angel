import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_jael/angel3_jael.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:file/memory.dart';
import 'package:html/parser.dart' as html;
import 'package:jael3/jael3.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  // These tests need not actually test that the preprocessor or renderer works,
  // because those packages are already tested.
  //
  // Instead, just test that we can render at all.
  late TestClient client;

  setUp(() async {
    var app = Angel();
    app.configuration['properties'] = app.configuration;

    var fileSystem = MemoryFileSystem();
    var viewsDirectory = fileSystem.directory('views')..createSync();

    viewsDirectory.childFile('layout.jael').writeAsStringSync('''
<!DOCTYPE html>
<html>
  <head>
    <title>Hello</title>
  </head>
  <body>
    <block name="content">
      Fallback content
    </block>
  </body>
</html>
    ''');

    viewsDirectory.childFile('github.jael').writeAsStringSync('''
<extend src="layout.jael">
  <block name="content">{{username}}</block>
</extend>
    ''');

    app.get('/github/:username', (req, res) async {
      var username = req.params['username'];
      return res.render('github', {'username': username});
    });

    //Preload the view template
    var viewCache = <String, Document>{};
    jaelTemplatePreload(viewsDirectory, viewCache);

    await app.configure(jael(viewsDirectory, cache: viewCache));

    app.fallback((req, res) => throw AngelHttpException.notFound());

    app.logger = Logger('angel')
      ..onRecord.listen((rec) {
        print(rec);
        if (rec.error != null) print(rec.error);
        if (rec.stackTrace != null) print(rec.stackTrace);
      });

    client = await connectTo(app);
  });

  test('can render', () async {
    var response = await client.get(Uri.parse('/github/thosakwe'));
    //print('Body:\n${response.body}');
    expect(
      html.parse(response.body).outerHtml,
      html
          .parse(
            '''<html><head><title>Hello</title></head><body>thosakwe</body></html>'''
                .trim(),
          )
          .outerHtml,
    );
  });

  test('initial load concurreny', () async {
    // Concurrently hit the same JAEL page
    for (var i = 0; i < 512; i++) {
      client.get(Uri.parse('/github/thosakwe'));
    }

    Stopwatch stopwatch = Stopwatch()..start();
    var response = await client.get(Uri.parse('/github/thosakwe'));
    var elapsedTime = stopwatch.elapsed.inMilliseconds;

    print('Latency is $elapsedTime');

    print('Body:\n${response.body}');
    expect(
      html.parse(response.body).outerHtml,
      html
          .parse(
            '''<html><head><title>Hello</title></head><body>thosakwe</body></html>'''
                .trim(),
          )
          .outerHtml,
    );
  });
}
