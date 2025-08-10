import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

final Directory swaggerUiDistDir = const LocalFileSystem().directory(
  'test/node_modules/swagger-ui-dist',
);

void main() async {
  late TestClient client;
  late String swaggerUiCssContents, swaggerTestJsContents;

  setUp(() async {
    // Load file contents
    swaggerUiCssContents = await const LocalFileSystem()
        .file(swaggerUiDistDir.uri.resolve('swagger-ui.css'))
        .readAsString();
    swaggerTestJsContents = await const LocalFileSystem()
        .file(swaggerUiDistDir.uri.resolve('test.js'))
        .readAsString();

    // Initialize app
    var app = Angel();
    app.logger = Logger('angel')..onRecord.listen(print);

    app.fallback(
      VirtualDirectory(
        app,
        const LocalFileSystem(),
        source: swaggerUiDistDir,
        publicPath: 'swagger/',
      ).handleRequest,
    );

    app.dumpTree();
    client = await connectTo(app);
  });

  tearDown(() => client.close());

  test('prefix is not replaced in file paths', () async {
    var response = await client.get(Uri.parse('/swagger/swagger-ui.css'));
    print('Response: ${response.body}');
    expect(response, hasBody(swaggerUiCssContents));
  });

  test('get a file without prefix in name', () async {
    var response = await client.get(Uri.parse('/swagger/test.js'));
    print('Response: ${response.body}');
    expect(response, hasBody(swaggerTestJsContents));
  });

  test('trailing slash at root', () async {
    var response = await client.get(Uri.parse('/swagger'));
    var body1 = response.body;
    print('Response #1: $body1');

    response = await client.get(Uri.parse('/swagger/'));
    var body2 = response.body;
    print('Response #2: $body2');

    expect(body1, body2);
  });
}
