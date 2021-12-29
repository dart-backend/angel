import 'package:angel3_framework/angel3_framework.dart';
import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:file/file.dart';
import 'package:jael3/jael3.dart';
import 'package:jael3_preprocessor/jael3_preprocessor.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';

/// Configures an Angel server to use Jael to render templates.
///
/// To enable "minified" output, set minified to true
///
/// For custom HTML formating, you need to override the [createBuffer] parameter
/// with a function that returns a new instance of [CodeBuffer].
///
/// To apply additional transforms to parsed documents, provide a set of [patch] functions.
AngelConfigurer jael(Directory viewsDirectory,
    {String fileExtension = '.jael',
    bool strictResolution = false,
    bool cacheViews = true,
    Map<String, Document>? cache,
    Iterable<Patcher> patch = const [],
    bool asDSX = false,
    bool minified = true,
    CodeBuffer Function()? createBuffer}) {
  var _cache = cache ?? <String, Document>{};

  var bufferFunc = createBuffer ?? () => CodeBuffer();

  if (minified) {
    bufferFunc = () => CodeBuffer(space: '', newline: '');
  }

  return (Angel app) async {
    app.viewGenerator = (String name, [Map? locals]) async {
      var errors = <JaelError>[];
      Document? processed;

      //var stopwatch = Stopwatch()..start();

      if (cacheViews && _cache.containsKey(name)) {
        processed = _cache[name];
      } else {
        processed = await _loadViewTemplate(viewsDirectory, name,
            fileExtension: fileExtension, asDSX: asDSX, patch: patch);

        if (cacheViews) {
          _cache[name] = processed!;
        }
      }
      //print('Time executed: ${stopwatch.elapsed.inMilliseconds}');
      //stopwatch.stop();

      var buf = bufferFunc();
      var scope = SymbolTable(
          values: locals?.keys.fold<Map<String, dynamic>>(<String, dynamic>{},
                  (out, k) => out..[k.toString()] = locals[k]) ??
              <String, dynamic>{});

      if (errors.isEmpty) {
        try {
          const Renderer().render(processed!, buf, scope,
              strictResolution: strictResolution);
          return buf.toString();
        } on JaelError catch (e) {
          errors.add(e);
        }
      }

      Renderer.errorDocument(errors, buf..clear());
      return buf.toString();
    };
  };
}

/// Preload all of Jael templates into a cache
///
///
/// To apply additional transforms to parsed documents, provide a set of [patch] functions.
Future<void> jaelTemplatePreload(
    Directory viewsDirectory, Map<String, Document> cache,
    {String fileExtension = '.jael',
    bool asDSX = false,
    Iterable<Patcher> patch = const []}) async {
  await viewsDirectory.list(recursive: true).forEach((f) async {
    if (f.basename.endsWith(fileExtension)) {
      var name = f.basename.split(".");
      if (name.length > 1) {
        //print("View: ${name[0]}");
        Document? processed = await _loadViewTemplate(viewsDirectory, name[0]);
        if (processed != null) {
          cache[name[0]] = processed;
        }
      }
    }
  });
}

Future<Document?> _loadViewTemplate(Directory viewsDirectory, String name,
    {String fileExtension = '.jael',
    bool asDSX = false,
    Iterable<Patcher> patch = const []}) async {
  var errors = <JaelError>[];
  Document? processed;

  var file = viewsDirectory.childFile(name + fileExtension);
  var contents = await file.readAsString();
  var doc = parseDocument(contents,
      sourceUrl: file.uri, asDSX: asDSX, onError: errors.add);

  if (doc == null) {
    throw ArgumentError(file.basename + " does not exists");
  }

  try {
    processed =
        await (resolve(doc, viewsDirectory, patch: patch, onError: errors.add));
  } catch (e) {
    // Ignore these errors, so that we can show syntax errors.
  }
  if (processed == null) {
    throw ArgumentError(file.basename + " does not exists");
  }
  return processed;
}
