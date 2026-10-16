import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';
import 'package:markdown/markdown.dart';

final RegExp _braces = RegExp(r'@?{{(((\\})|([^}]))+)}}');

/// The private-use characters that start and end the placeholder that stands
/// for a value while the Markdown is parsed. Markdown leaves them as they are,
/// or percent-encodes them, as in the URL of a link.
final String _placeholderStart = String.fromCharCode(0xE000);
final String _placeholderEnd = String.fromCharCode(0xE001);
const String _encodedPlaceholderStart = '%EE%80%80';
const String _encodedPlaceholderEnd = '%EE%80%81';

/// Escapes text for HTML content and for attributes in single or double
/// quotes. Unlike [htmlEscape], it leaves `/` as it is, so that URLs stay
/// readable.
const HtmlEscape _htmlEscape = HtmlEscape(
  HtmlEscapeMode(escapeLtGt: true, escapeQuot: true, escapeApos: true),
);

/// What is percent-encoded in a whole URL: a `%` that does not start an
/// escape, and any character that cannot appear in a URL.
final RegExp _unsafeUrlCharacters = RegExp(
  r"%(?![0-9A-Fa-f]{2})|[^A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]",
  unicode: true,
);

/// The scheme of a URL, such as `https` in `https://...`.
final RegExp _scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):');

/// The schemes that a URL with values may have. Others, such as `javascript:`
/// or `data:`, could run script when the link is followed.
const Set<String> _safeSchemes = {'http', 'https', 'mailto'};

/// The attributes of Markdown elements that hold a URL.
const Set<String> _urlAttributes = {'href', 'src'};

/// Marks a member that [_readGetter] does not know.
const Object _missing = Object();

final Random _random = Random();

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
/// HTML-escaped, so that they appear as text in HTML content (also in code
/// and tables) and in quoted HTML attributes, and HTML or Markdown in them is
/// not rendered. In the URL of a Markdown link or image they are also
/// percent-encoded: a value that starts the URL as a URL, and a value after
/// other text of the URL (e.g. `/search?q={{q}}`) as a component of it, so
/// that its `/`, `?`, `&` and `#` are encoded too. A URL with values whose
/// scheme is not `http`, `https` or `mailto` (such as `javascript:`), or that
/// starts with a value and `//` (another host), is replaced with `#`. URLs in
/// HTML attributes are not checked. Values are not escaped for JavaScript or
/// CSS,
/// so they must not be put into `<script>` or `<style>` elements or into
/// event handler attributes such as `onclick`. Set [escape] to `false` to
/// insert them into the Markdown before it is rendered instead, only for
/// values that are trusted.
///
/// A view name that resolves outside [viewsDirectory] (e.g. `../secret`), also
/// through a symbolic link, or to no file, throws a 404 [AngelHttpException].
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
      var fileSystem = viewsDirectory.fileSystem;
      var path = fileSystem.path;
      var root = path.normalize(viewsDirectory.absolute.path);
      var filePath = path.normalize(
        path.join(root, path.setExtension(name, extension!)),
      );
      // A view that does not exist is not found either, as one outside the
      // views directory is.
      if (!path.isWithin(root, filePath) ||
          !await fileSystem.file(filePath).exists()) {
        throw AngelHttpException.notFound();
      }

      // Also stay inside the views directory through symbolic links, and read
      // the file that was checked. The views directory is resolved on every
      // render, as it may be a link that a deployment points elsewhere.
      var resolvedViewsPath = await viewsDirectory.resolveSymbolicLinks();
      var resolvedFilePath = await fileSystem
          .file(filePath)
          .resolveSymbolicLinks();
      if (!path.isWithin(resolvedViewsPath, resolvedFilePath)) {
        throw AngelHttpException.notFound();
      }

      var contents = await fileSystem.file(resolvedFilePath).readAsString();
      var placeholders = _Placeholders();
      var jsonCache = Map<Object, dynamic>.identity();

      contents = contents.replaceAllMapped(_braces, (m) {
        var text = m[0]!;

        if (text.startsWith('@')) {
          // Raw braces
          return text.substring(1);
        } else {
          var expr = m[1]!;
          var split = [for (var part in expr.split('.')) part.trim()];
          var localName = split[0];

          if (locals?.containsKey(localName) != true) {
            throw UnimplementedError(
              'Expected a local named "$localName", but none was provided. Expression text: "$text"',
            );
          }

          // A null value renders as nothing, not as the text "null".
          var value = _resolveDotNotation(
            split,
            locals![localName],
            jsonCache,
          )?.toString();
          if (value == null) return '';
          return escape ? placeholders.add(value) : value;
        }
      });

      var nodes = Document(
        extensionSet: placeholders.isNotEmpty
            ? placeholders.extensionSetFor(extensionSet!)
            : extensionSet,
      ).parse(contents);
      if (placeholders.isNotEmpty) placeholders.fill(nodes);

      var html = '${renderToHtml(nodes)}\n';
      if (template != null) html = await template(html, locals ?? {});
      return html;
    };
  };
}

/// The values of the expressions in one render, which the Markdown is parsed
/// with placeholders for, and which [fill] then puts into the parsed nodes.
///
/// The placeholder of the n-th value is U+E000, a key, n, the key again and
/// U+E001, where the key is random letters, so that no text of the view is
/// taken for a placeholder. Equal values have the same placeholder, so that
/// text that Markdown compares, such as the label of a reference link and of
/// its definition, is still equal.
class _Placeholders {
  final List<String> _values = [];
  final Map<String, int> _indexes = {};

  final String _key = String.fromCharCodes([
    for (var i = 0; i < 8; i++) 0x61 + _random.nextInt(26),
  ]);

  late final RegExp _pattern = RegExp(
    '($_placeholderStart|$_encodedPlaceholderStart)$_key'
    r'(\d+)'
    '$_key(?:$_placeholderEnd|$_encodedPlaceholderEnd)',
  );

  bool get isNotEmpty => _values.isNotEmpty;

  /// Returns the placeholder for [value].
  String add(String value) {
    var index = _indexes.putIfAbsent(value, () {
      _values.add(value);
      return _values.length - 1;
    });
    return '$_placeholderStart$_key$index$_key$_placeholderEnd';
  }

  /// [extensionSet], with its syntaxes that generate the ids of headings
  /// replaced by ones that generate them from the Markdown of the heading with
  /// the values, as for the Markdown that has them. Subclasses of them, which
  /// may generate ids differently, are kept.
  ExtensionSet extensionSetFor(ExtensionSet extensionSet) => ExtensionSet([
    for (var syntax in extensionSet.blockSyntaxes)
      if (syntax.runtimeType == HeaderWithIdSyntax)
        _HeaderWithIdSyntax(this)
      else if (syntax.runtimeType == SetextHeaderWithIdSyntax)
        _SetextHeaderWithIdSyntax(this)
      else
        syntax,
  ], extensionSet.inlineSyntaxes);

  /// Generates the id of [heading] again, as [BlockSyntax.generateAnchorHash]
  /// does from its Markdown, which it still has, with the values.
  Element _generateId(Element heading) {
    var children = heading.children;
    if (heading.generatedId != null && children != null) {
      var markdown = children.first.textContent.replaceAllMapped(
        _pattern,
        (m) => _values[int.parse(m[2]!)],
      );
      heading.generatedId = BlockSyntax.generateAnchorHash(
        Element('h1', [Text(markdown)]),
      );
    }
    return heading;
  }

  /// Replaces the placeholders in the text and attributes of [nodes] with
  /// their values, HTML-escaped, and in the URLs of `href` and `src`
  /// attributes as [_fillUrl] does.
  void fill(List<Node> nodes) {
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (node is Text) {
        nodes[i] = Text(_fillText(node.text));
      } else if (node is Element) {
        node.attributes.updateAll(
          (name, value) => _urlAttributes.contains(name)
              ? _fillUrl(value)
              : _fillText(value),
        );
        var children = node.children;
        if (children != null) fill(children);
      }
    }
  }

  String _fillText(String text) => text.replaceAllMapped(
    _pattern,
    (m) => _htmlEscape.convert(_values[int.parse(m[2]!)]),
  );

  /// Puts the values into [url], percent-encoded: a value that starts it as a
  /// URL, and other values as a component of it. The URL that results is
  /// replaced with `#` when its scheme is not one of [_safeSchemes], or when
  /// it starts with a value and `//`, i.e. links to the host of a value.
  String _fillUrl(String url) {
    if (!_pattern.hasMatch(url)) return url;

    String encode(Match m) {
      var value = _withoutLoneSurrogates(_values[int.parse(m[2]!)]);
      return m.start == 0
          ? value.replaceAllMapped(
              _unsafeUrlCharacters,
              (m) => Uri.encodeComponent(m[0]!),
            )
          : Uri.encodeComponent(value);
    }

    // The text of the URL around the values is already percent-encoded.
    var filled = url.replaceAllMapped(_pattern, encode);
    var scheme = _scheme.firstMatch(filled)?[1]?.toLowerCase();
    if ((scheme != null && !_safeSchemes.contains(scheme)) ||
        (_pattern.matchAsPrefix(url) != null && filled.startsWith('//'))) {
      return '#';
    }

    return url.replaceAllMapped(
      _pattern,
      (m) => _htmlEscape.convert(encode(m)),
    );
  }
}

/// Generates the id of a heading as for its Markdown with the values of
/// [_placeholders].
mixin _GeneratesIdWithValues on BlockSyntax {
  _Placeholders get _placeholders;

  @override
  Node parse(BlockParser parser) =>
      _placeholders._generateId(super.parse(parser)! as Element);
}

class _HeaderWithIdSyntax extends HeaderWithIdSyntax
    with _GeneratesIdWithValues {
  @override
  final _Placeholders _placeholders;

  _HeaderWithIdSyntax(this._placeholders);
}

class _SetextHeaderWithIdSyntax extends SetextHeaderWithIdSyntax
    with _GeneratesIdWithValues {
  @override
  final _Placeholders _placeholders;

  _SetextHeaderWithIdSyntax(this._placeholders);
}

/// [text] with each unpaired surrogate replaced by U+FFFD, as
/// [Uri.encodeComponent] cannot encode one.
String _withoutLoneSurrogates(String text) => String.fromCharCodes(
  text.runes.map((r) => r >= 0xD800 && r <= 0xDFFF ? 0xFFFD : r),
);

dynamic _resolveDotNotation(
  List<String> split,
  target,
  Map<Object, dynamic> jsonCache,
) {
  for (var i = 1; i < split.length; i++) {
    target = _readMember(target, split, i, jsonCache);
  }

  return target;
}

/// Reads the [i]-th part of the expression [split] from [target], the value of
/// the parts before it: a key of a [Map], an index of a [List], a common
/// getter of a [String], [Iterable] or [Map] (see [_readGetter]), or else a
/// key of what `toJson()` returns, as for `@serializable` models. What
/// `toJson()` returns is kept in [jsonCache] for the rest of the render.
dynamic _readMember(
  dynamic target,
  List<String> split,
  int i,
  Map<Object, dynamic> jsonCache,
) {
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
    var json = jsonCache.putIfAbsent(target, () {
      try {
        return (target as dynamic).toJson();
      } on NoSuchMethodError catch (e) {
        // Only report that this object has no toJson(), not an error inside
        // one, such as another object without toJson().
        if (!'$e'.contains(
          "Class '${target.runtimeType}' has no instance method 'toJson'",
        )) {
          rethrow;
        }
        throw ArgumentError(
          'Cannot read "$name" of "${path()}", a ${target.runtimeType}. '
          'Locals must be Maps, or have a toJson() method that returns one.',
        );
      }
    });
    // Only the keys of the JSON are members of the object, not the getters of
    // the Map.
    if (json is Map && json.containsKey(name)) return json[name];
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
