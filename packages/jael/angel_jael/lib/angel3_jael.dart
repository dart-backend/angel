import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:file/file.dart';
import 'package:jael3/jael3.dart';
import 'package:jael3_preprocessor/jael3_preprocessor.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';

/// A [MemberResolver] that reads the members of values through [reflector]:
/// a `StaticReflector`, of the members `angel3_container_generator` generates
/// for `@injectable` classes, or a `MirrorsReflector`, of any. It knows none
/// of a value [reflector] cannot reflect upon, as of the default
/// `ThrowingReflector`, nor of a `Map`, a `String`, a number, a `bool` or an
/// `Iterable`, which the renderer reads.
MemberResolver reflectorMemberResolver(Reflector reflector) {
  if (reflector is ThrowingReflector) return (target, name) => noMember;
  return (target, name) {
    if (target == null ||
        target is Map ||
        target is String ||
        target is num ||
        target is bool ||
        target is Iterable) {
      return noMember;
    }
    try {
      var instance = reflector.reflectInstance(target);
      if (instance == null) return noMember;
      return instance.getField(name).reflectee;
    } on ReflectionException {
      return noMember;
    } on ArgumentError {
      // A `StaticReflector` without data about the class.
      return noMember;
    } on UnsupportedError {
      return noMember;
    } on NoSuchMethodError {
      // A `MirrorsReflector`, of a member the value does not have.
      return noMember;
    }
  };
}

/// Configures an Angel server to use Jael to render templates.
///
/// To enable "minified" output, set minified to true
///
/// For custom HTML formating, you need to override the [createBuffer] parameter
/// with a function that returns a new instance of [CodeBuffer].
///
/// To apply additional transforms to parsed documents, provide a set of [patch] functions.
///
/// The members of values, `{{ user.name }}`, are read by [memberResolver], if
/// it knows them, and else through the app's reflector, of
/// [reflectorMemberResolver], before the ways of `Renderer.render`. Give the
/// app a `StaticReflector` of the data `angel3_container_generator` generates
/// for your `@injectable` classes to read their members without
/// `dart:mirrors`.
AngelConfigurer jael(
  Directory viewsDirectory, {
  String fileExtension = '.jael',
  bool strictResolution = false,
  bool cacheViews = true,
  Map<String, Document>? cache,
  Iterable<Patcher> patch = const [],
  bool asDSX = false,
  bool minified = true,
  CodeBuffer Function()? createBuffer,
  MemberResolver? memberResolver,
}) {
  var localCache = cache ?? <String, Document>{};

  var bufferFunc = createBuffer ?? () => CodeBuffer();

  if (minified) {
    bufferFunc = () => CodeBuffer(space: '', newline: '');
  }

  return (Angel app) async {
    var fromReflector = reflectorMemberResolver(app.container.reflector);
    MemberResolver resolver = memberResolver == null
        ? fromReflector
        : (target, name) {
            var value = memberResolver(target, name);
            return identical(value, noMember)
                ? fromReflector(target, name)
                : value;
          };

    app.viewGenerator = (String name, [Map? locals]) async {
      var errors = <JaelError>[];
      Document? processed;

      //var stopwatch = Stopwatch()..start();

      if (cacheViews && localCache.containsKey(name)) {
        processed = localCache[name];
      } else {
        processed = await _loadViewTemplate(
          viewsDirectory,
          name,
          fileExtension: fileExtension,
          asDSX: asDSX,
          patch: patch,
        );

        if (cacheViews) {
          localCache[name] = processed!;
        }
      }
      //print('Time executed: ${stopwatch.elapsed.inMilliseconds}');
      //stopwatch.stop();

      var buf = bufferFunc();
      var scope = SymbolTable(
        values:
            locals?.keys.fold<Map<String, dynamic>>(
              <String, dynamic>{},
              (out, k) => out..[k.toString()] = locals[k],
            ) ??
            <String, dynamic>{},
      );

      if (errors.isEmpty) {
        try {
          const Renderer().render(
            processed!,
            buf,
            scope,
            strictResolution: strictResolution,
            memberResolver: resolver,
          );
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
  Directory viewsDirectory,
  Map<String, Document> cache, {
  String fileExtension = '.jael',
  bool asDSX = false,
  Iterable<Patcher> patch = const [],
}) async {
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

Future<Document?> _loadViewTemplate(
  Directory viewsDirectory,
  String name, {
  String fileExtension = '.jael',
  bool asDSX = false,
  Iterable<Patcher> patch = const [],
}) async {
  var errors = <JaelError>[];
  Document? processed;

  var file = viewsDirectory.childFile(name + fileExtension);
  var contents = await file.readAsString();
  var doc = parseDocument(
    contents,
    sourceUrl: file.uri,
    asDSX: asDSX,
    onError: errors.add,
  );

  if (doc == null) {
    throw ArgumentError("${file.basename} does not exists");
  }

  try {
    processed = await (resolve(
      doc,
      file.parent,
      patch: patch,
      onError: errors.add,
    ));
  } catch (e) {
    // Ignore these errors, so that we can show syntax errors.
  }
  if (processed == null) {
    throw ArgumentError("${file.basename} does not exists");
  }
  return processed;
}
