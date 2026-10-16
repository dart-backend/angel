import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';
import 'package:markdown/markdown.dart';

final RegExp _braces = RegExp(r'@?{{(((\\})|([^}]))+)}}');

/// What stands in for the value of the n-th expression while the Markdown is
/// parsed: `n`, made of private-use characters that Markdown
/// leaves as they are, or percent-encoded, as in the URL of a link.
final RegExp _placeholders = RegExp('(?:|%EE%80%80)(\\d+)(?:|%EE%80%81)');

/// Escapes text for HTML content and for attributes in single or double
/// quotes.
const HtmlEscape _htmlEscape = HtmlEscape(
  HtmlEscapeMode(escapeLtGt: true, escapeQuot: true, escapeApos: true),
);

/// Marks a member that [_readGetter] does not know.
const Object _missing = Object();

/// Configures an [Angel] instance to render Markdown templates from the specified [viewsDirectory].
///
/// The default [extension] is `.md`. To search for a different file extension, provide a new one.
/// By default, an [extensionSet] is provided that renders Github-flavored Markdown. This can also be overridden.
///
/// In many cases, Markdown content will be rendered within a larger [template] that styles the entire website.
/// To wrap generated Markdown content in a template, provide a function that accepts a generated HTML String,
/// and returns a String, or a `Future<String>`.
///
/// The values of `{{...}}` expressions are put into the rendered HTML,
/// HTML-escaped, so that they appear exactly as text wherever they are (also
/// in code, tables and HTML attributes), and HTML or Markdown in them is not
/// rendered. Set [escape] to `false` to insert them into the Markdown before
/// it is rendered instead, only for values that are trusted.
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
      var values = <String>[];

      contents = contents.replaceAllMapped(_braces, (m) {
        var text = m[0]!;

        if (text.startsWith('@')) {
          // Raw braces
          return text.substring(1);
        } else {
          var expr = m[1]!;
          var split = [for (var part in expr.split('.')) part.trim()];
          var root = split[0];

          if (locals?.containsKey(root) != true) {
            throw UnimplementedError(
              'Expected a local named "$root", but none was provided. Expression text: "$text"',
            );
          }

          // A null value renders as nothing, not as the text "null".
          var value = _resolveDotNotation(split, locals![root])?.toString();
          if (value == null) return '';
          if (!escape) return value;

          values.add(value);
          return '${values.length - 1}';
        }
      });

      var nodes = Document(extensionSet: extensionSet).parse(contents);
      if (values.isNotEmpty) _fillPlaceholders(nodes, values);

      var html = '${renderToHtml(nodes)}\n';
      if (template != null) html = await template(html, locals ?? {});
      return html;
    };
  };
}

/// Replaces the placeholders in the text and attributes of [nodes] with the
/// [values] they stand for, HTML-escaped, and regenerates the ids of headings
/// from their text with the values.
void _fillPlaceholders(List<Node> nodes, List<String> values) {
  String fill(String text) => text.replaceAllMapped(
    _placeholders,
    (m) => _htmlEscape.convert(values[int.parse(m[1]!)]),
  );

  for (var i = 0; i < nodes.length; i++) {
    var node = nodes[i];
    if (node is Text) {
      nodes[i] = Text(fill(node.text));
    } else if (node is Element) {
      node.attributes.updateAll((_, value) => fill(value));
      var children = node.children;
      if (children != null) _fillPlaceholders(children, values);
      if (node.generatedId != null) {
        node.generatedId = BlockSyntax.generateAnchorHash(node);
      }
    }
  }
}

dynamic _resolveDotNotation(List<String> split, target) {
  for (var i = 1; i < split.length; i++) {
    target = _readMember(target, split, i);
  }

  return target;
}

/// Reads the [i]-th part of the expression [split] from [target], the value of
/// the parts before it: a key of a [Map], an index of a [List], a common
/// getter of a [String], [Iterable] or [Map] (see [_readGetter]), or else a
/// key of what `toJson()` returns, as for `@serializable` models.
dynamic _readMember(dynamic target, List<String> split, int i) {
  var name = split[i];
  String path() => split.take(i).join('.');

  if (target == null) {
    throw ArgumentError('Cannot read "$name" of "${path()}", which is null.');
  }

  if (target is Map && target.containsKey(name)) return target[name];

  if (target is List) {
    var index = int.tryParse(name);
    if (index != null) {
      if (index >= 0 && index < target.length) return target[index];
      throw ArgumentError(
        '"${path()}" has ${target.length} items, so it has no item $index.',
      );
    }
  }

  var value = _readGetter(target, name);
  if (!identical(value, _missing)) return value;

  if (target is! Map && target is! Iterable && target is! String) {
    dynamic json;
    try {
      json = (target as dynamic).toJson();
    } on NoSuchMethodError {
      throw ArgumentError(
        'Cannot read "$name" of "${path()}", a ${target.runtimeType}. Locals '
        'must be Maps, or have a toJson() method that returns one.',
      );
    }
    if (json is Map) return _readMember(json, split, i);
  }

  throw ArgumentError('"${path()}" has no member named "$name".');
}

/// Reads one of the common getters of a [String], [Iterable] or [Map], or
/// returns [_missing]. `first` and `last` of an empty [Iterable] are `null`.
Object? _readGetter(Object target, String name) => switch ((target, name)) {
  (String s, 'length') => s.length,
  (String s, 'isEmpty') => s.isEmpty,
  (String s, 'isNotEmpty') => s.isNotEmpty,
  (Iterable it, 'length') => it.length,
  (Iterable it, 'isEmpty') => it.isEmpty,
  (Iterable it, 'isNotEmpty') => it.isNotEmpty,
  (Iterable it, 'first') => it.isEmpty ? null : it.first,
  (Iterable it, 'last') => it.isEmpty ? null : it.last,
  (Map m, 'length') => m.length,
  (Map m, 'isEmpty') => m.isEmpty,
  (Map m, 'isNotEmpty') => m.isNotEmpty,
  _ => _missing,
};
