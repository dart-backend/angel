import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_mustache/angel3_mustache.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

const FileSystem fs = LocalFileSystem();

void configureServer(Angel app) async {
  // Run the plug-in
  await app.configure(mustache(fs.directory('views')));

  // Render `hello.mustache`
  app.get('/', (req, res) async {
    await res.render('hello', {'name': 'world'});
  });
}
