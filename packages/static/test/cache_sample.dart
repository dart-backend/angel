import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/local.dart';

void main() async {
  Angel app;
  AngelHttp http;
  var testDir = const LocalFileSystem().directory('test');
  app = Angel();
  http = AngelHttp(app);

  app.fallback(
    CachingVirtualDirectory(app, const LocalFileSystem(),
        source: testDir,
        maxAge: 350,
        onlyInProduction: false,
        indexFileNames: ['index.txt']).handleRequest,
  );

  app.get('*', (req, res) => 'Fallback');

  app.dumpTree(showMatchers: true);

  var server = await http.startServer();
  print('Open at http://${server.address.host}:${server.port}');
}
