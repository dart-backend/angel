import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/local.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  var app = Angel();
  var http = AngelHttp(app);
  var fs = const LocalFileSystem();
  var vDir = CachingVirtualDirectory(
    app,
    fs,
    allowDirectoryListing: true,
    source: args.isEmpty ? fs.currentDirectory : fs.directory(args[0]),
    maxAge: const Duration(days: 24).inSeconds,
  );

  app.mimeTypeResolver
    ..addExtension('', 'text/plain')
    ..addExtension('dart', 'text/dart')
    ..addExtension('lock', 'text/plain')
    ..addExtension('markdown', 'text/plain')
    ..addExtension('md', 'text/plain')
    ..addExtension('yaml', 'text/plain');

  app.logger = Logger('example')
    ..onRecord.listen((rec) {
      print(rec);
      if (rec.error != null) print(rec.error);
      if (rec.stackTrace != null) print(rec.stackTrace);
    });

  app.fallback(vDir.handleRequest);
  app.fallback((req, res) => throw AngelHttpException.notFound());

  var server = await http.startServer('127.0.0.1', 3000);
  print('Serving from ${vDir.source!.path}');
  print('Listening at http://${server.address.address}:${server.port}');
}
