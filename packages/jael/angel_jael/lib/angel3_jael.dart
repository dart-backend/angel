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
    Iterable<Patcher> patch = const [],
    bool asDSX = false,
    bool minified = true,
    CodeBuffer Function()? createBuffer}) {
  var cache = <String, Document>{};

  var bufferFunc = createBuffer ?? () => CodeBuffer();

  if (minified) {
    bufferFunc = () => CodeBuffer(space: '', newline: '');
  }

  return (Angel app) async {
    app.viewGenerator = (String name, [Map? locals]) async {
      var errors = <JaelError>[];
      Document? processed;

      if (cacheViews && cache.containsKey(name)) {
        processed = cache[name];
      } else {
        var file = viewsDirectory.childFile(name + fileExtension);
        var contents = await file.readAsString();
        var doc = parseDocument(contents,
            sourceUrl: file.uri, asDSX: asDSX, onError: errors.add);
        if (doc == null) {
          throw ArgumentError(name + fileExtension + " does not exists");
        }

        try {
          processed = await (resolve(doc, viewsDirectory,
              patch: patch, onError: errors.add));
        } catch (e) {
          // Ignore these errors, so that we can show syntax errors.
        }
        if (processed == null) {
          throw ArgumentError(name + fileExtension + " does not exists");
        }

        if (cacheViews) {
          cache[name] = processed;
        }
      }

      var buf = bufferFunc();
      var scope = SymbolTable(
          values: locals?.keys.fold<Map<String, dynamic>>(<String, dynamic>{},
                  (out, k) => out..[k.toString()] = locals[k]) ??
              <String, dynamic>{});

      if (errors.isEmpty) {
        try {
          const Renderer().render(processed!, buf, scope,
              strictResolution: strictResolution == true);
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
