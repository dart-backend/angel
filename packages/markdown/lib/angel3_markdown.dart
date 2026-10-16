import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';
import 'package:markdown/markdown.dart';

final RegExp _braces = RegExp(r'@?{{(((\\})|([^}]))+)}}');

/// ASCII punctuation, which Markdown lets a backslash escape.
final RegExp _punctuation = RegExp(r'[!-/:-@\[-`{-~]');

/// Configures an [Angel] instance to render Markdown templates from the specified [viewsDirectory].
///
/// The default [extension] is `.md`. To search for a different file extension, provide a new one.
/// By default, an [extensionSet] is provided that renders Github-flavored Markdown. This can also be overridden.
///
/// In many cases, Markdown content will be rendered within a larger [template] that styles the entire website.
/// To wrap generated Markdown content in a template, provide a function that accepts a generated HTML String,
/// and returns a String, or a `Future<String>`.
///
/// The values of `{{...}}` expressions are escaped, so that they appear as
/// text, and HTML or Markdown in them is not rendered. Set [escape] to `false`
/// to insert them as Markdown instead, only for values that are trusted.
///
/// A view name that resolves outside [viewsDirectory] (e.g. `../secret`)
/// throws a 404 [AngelHttpException].
AngelConfigurer markdown(
  Directory viewsDirectory, {
  String? extension,
  ExtensionSet? extensionSet,
  FutureOr<String> Function(String content, Map<String, dynamic> locals)?
  template,
  bool escape = true,
}) {
  extension ??= '.md';
  extensionSet ??= ExtensionSet.gitHubWeb;

  return (Angel app) async {
    app.viewGenerator = (String name, [Map<String, dynamic>? locals]) async {
      var path = viewsDirectory.fileSystem.path;
      var root = path.normalize(viewsDirectory.absolute.path);
      var filePath = path.normalize(
        path.join(root, path.setExtension(name, extension!)),
      );
      if (!path.isWithin(root, filePath)) {
        throw AngelHttpException.notFound();
      }

      var file = viewsDirectory.fileSystem.file(filePath);
      var contents = await file.readAsString();

      contents = contents.replaceAllMapped(_braces, (m) {
        var text = m[0]!;

        if (text.startsWith('@')) {
          // Raw braces
          return text.substring(1);
        } else {
          var expr = m[1]!;
          var split = expr.split('.');
          var root = split[0];

          if (locals?.containsKey(root) != true) {
            throw UnimplementedError(
              'Expected a local named "$root", but none was provided. Expression text: "$text"',
            );
          }

          var value = _resolveDotNotation(split, locals![root]).toString();
          return escape ? _escapeMarkdown(value) : value;
        }
      });

      var html = markdownToHtml(contents, extensionSet: extensionSet);
      if (template != null) html = await template(html, locals ?? {});
      return html;
    };
  };
}

/// Backslash-escapes the punctuation in [text], so that Markdown renders it as
/// text: `<` becomes `&lt;` rather than a tag, and `*` or `[` stay as they are.
String _escapeMarkdown(String text) =>
    text.replaceAllMapped(_punctuation, (m) => '\\${m[0]}');

dynamic _resolveDotNotation(List<String> split, target) {
  for (var i = 1; i < split.length; i++) {
    target = _readMember(target, split[i], split.take(i).join('.'));
  }

  return target;
}

/// Reads [name] from [target], the value of the expression [path]: a key of a
/// [Map], or else of what its `toJson()` returns, as `@serializable` models do.
dynamic _readMember(dynamic target, String name, String path) {
  if (target == null) {
    throw ArgumentError('Cannot read "$name" of "$path", which is null.');
  }

  if (target is! Map) {
    try {
      target = (target as dynamic).toJson();
    } on NoSuchMethodError {
      throw ArgumentError(
        'Cannot read "$name" of "$path", a ${target.runtimeType}. Locals must '
        'be Maps, or have a toJson() method that returns one.',
      );
    }
  }

  if (target is! Map || !target.containsKey(name)) {
    throw ArgumentError('"$path" has no member named "$name".');
  }

  return target[name];
}
