library;

import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';
import 'package:mustache_template/mustache_template.dart' as viewer;
import 'package:path/path.dart' as p;
import 'src/cache.dart';
import 'src/mustache_context.dart';

Future Function(Angel app) mustache(
  Directory viewsDirectory, {
  String fileExtension = '.mustache',
  String partialsPath = './partials',
}) {
  var partialsDirectory = viewsDirectory.fileSystem.directory(
    p.join(p.fromUri(viewsDirectory.uri), partialsPath),
  );

  var context = MustacheContext(
    viewsDirectory,
    partialsDirectory,
    fileExtension,
  );

  var cache = MustacheViewCache(context);

  return (Angel app) async {
    app.viewGenerator = (String name, [Map? data]) async {
      //var partialsProvider;
      partialsProvider(String name) {
        var template = cache.getPartialSync(name, app)!;
        //return render(template, data ?? {}, partial: partialsProvider);
        return viewer.Template(template, name: name);
      }

      var viewTemplate = await (cache.getView(name, app));
      //return await render(viewTemplate, data ?? {}, partial: partialsProvider);
      var t = viewer.Template(
        viewTemplate ?? '',
        partialResolver: partialsProvider,
      );
      return t.renderString(data ?? {});
    };
  };
}
