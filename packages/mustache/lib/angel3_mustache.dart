library;

import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';

import 'src/cache.dart';
import 'src/mustache_context.dart';

/// Renders the Mustache views in [viewsDirectory], with the partials in
/// [partialsPath] within it.
///
/// A view name that resolves outside [viewsDirectory] (e.g. `../secret`), also
/// through a symbolic link, or to no file, throws a 404 [AngelHttpException].
/// A partial outside the partials directory, or that does not exist, renders
/// as nothing.
Future Function(Angel app) mustache(
  Directory viewsDirectory, {
  String fileExtension = '.mustache',
  String partialsPath = './partials',
}) {
  var partialsDirectory = viewsDirectory.childDirectory(partialsPath);

  var context = MustacheContext(
    viewsDirectory,
    partialsDirectory,
    fileExtension,
  );

  var cache = MustacheViewCache(context);

  return (Angel app) async {
    app.viewGenerator = (String name, [Map? data]) =>
        cache.render(name, data, app);
  };
}
