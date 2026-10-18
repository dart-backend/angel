import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';
import 'package:markdown/markdown.dart';

final RegExp _braces = RegExp(r'@?{{(((\\})|([^}]))+)}}');

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

/// The scheme of a URL, such as `https:` in `https://...`.
final RegExp _scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):');

/// The schemes that values may give a URL. Others, such as `javascript:` or
/// `data:`, could run script when the link is followed.
const Set<String> _safeSchemes = {'http', 'https', 'mailto'};

/// Start tags after which the browser reads text up to their end tag, not
/// tags, and so does [_HtmlScanner].
const Set<String> _textElements = {
  'textarea', 'title', // RCDATA
  'style', 'xmp', 'iframe', 'noembed', 'noframes', 'noscript', // RAWTEXT
};

/// Start tags after which [_HtmlScanner] cannot follow the browser: `<script>`
/// has escape states of its own, `<plaintext>` never ends, and in `<svg>` and
/// `<math>` the elements above are not text and `<![CDATA[` is a section.
const Set<String> _untrackedElements = {'script', 'plaintext', 'svg', 'math'};

/// Each character of a string.
final RegExp _character = RegExp('.', dotAll: true, unicode: true);

/// What [AutolinkSyntax] and [EmailAutolinkSyntax] take for the URL of an
/// autolink, such as `<https://example.com>` or `<a@example.com>`.
final RegExp _autolinkUrl = RegExp(r'^[a-zA-Z][a-zA-Z\-+.]+:(?://)?[^\s<>]*$');
final RegExp _autolinkEmail = RegExp(
  r'''^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}'''
  r'''[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$''',
);

/// The attributes of Markdown elements that hold a URL.
const Set<String> _urlAttributes = {'href', 'src'};

/// What [BlockSyntax.generateAnchorHash] removes from the text of a heading.
final RegExp _anchorUnsafe = RegExp('[^a-z0-9 _-]');
final RegExp _whitespace = RegExp(r'\s');

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
/// not rendered. Raw HTML is read as the browser reads it: in HTML tags
/// outside quotes, as in `<img src={{x}}>`, in `<textarea>`, `<title>`,
/// `<style>` and the like, and anywhere after `<script>`, `<svg>` or `<math>`,
/// each character of values is encoded as a character reference, so that they
/// cannot be the name of a tag or attribute or add attributes; such values
/// still read as text in attribute values. `<{{url}}>` is an autolink when the
/// value is a URL or email address. In the URL of a Markdown link or image they are also
/// percent-encoded: a value that starts the URL as a URL, and a value after
/// other text of the URL (e.g. `/search?q={{q}}`) as a component of it, so
/// that its `/`, `?`, `&` and `#` are encoded too. A URL whose scheme values
/// make (e.g. `[x]({{url}})` with `javascript:...`) is replaced with `#`
/// unless the scheme is `http`, `https` or `mailto`; a scheme in the view
/// itself, as in `[x](tel:{{phone}})`, is kept. URLs in HTML attributes are
/// not checked. Values are not escaped for JavaScript or CSS, so they must not
/// be put into `<script>` or `<style>` elements or into event handler
/// attributes such as `onclick`. Set [escape] to `false` to insert them into
/// the Markdown before it is rendered instead, only for values that are
/// trusted.
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
      if (!path.isWithin(root, filePath)) {
        throw AngelHttpException.notFound();
      }

      // Also stay inside the views directory through symbolic links, and read
      // the file that was checked. The views directory is resolved on every
      // render, as it may be a link that a deployment points elsewhere.
      String contents;
      try {
        var resolvedViewsPath = await viewsDirectory.resolveSymbolicLinks();
        var resolvedFilePath = await fileSystem
            .file(filePath)
            .resolveSymbolicLinks();
        if (!path.isWithin(resolvedViewsPath, resolvedFilePath)) {
          throw AngelHttpException.notFound();
        }
        contents = await fileSystem.file(resolvedFilePath).readAsString();
      } on FileSystemException {
        // A view (or views directory) that does not exist, or a view that is
        // not a file, is not found either.
        throw AngelHttpException.notFound();
      }

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
          if (!escape) return value;
          var input = m.input;
          return placeholders.add(
            value,
            autolink:
                m.start > 0 &&
                input[m.start - 1] == '<' &&
                m.end < input.length &&
                input[m.end] == '>',
          );
        }
      });

      var nodes = Document(
        extensionSet: placeholders.isNotEmpty
            ? placeholders.extensionSetFor(extensionSet!)
            : extensionSet,
      ).parse(contents);
      if (placeholders.isNotEmpty) placeholders.fill(nodes);

      var html = renderToHtml(nodes);
      if (placeholders.isNotEmpty) html = placeholders.fillHtml(html);
      html = '$html\n';
      if (template != null) html = await template(html, locals ?? {});
      return html;
    };
  };
}

/// The values of the expressions in one render, which the Markdown is parsed
/// with placeholders for, and which [fill] then puts into the parsed nodes.
///
/// The placeholder of the n-th value is a key, n and the key again, where the
/// key is random lowercase letters, so that no text of the view is taken for a
/// placeholder. A value in `<>`, as in `<{{url}}>`, has a key that starts with
/// a digit instead, so that Markdown does not take it for an HTML tag, whose
/// name starts with a letter, and [_PlaceholderAutolinkSyntax] renders it.
/// Elsewhere a placeholder starts with a letter, so that, as for a value in
/// raw HTML, `<{{x}}>` is an HTML tag for Markdown. Markdown leaves letters and
/// digits as they are wherever they are: in text, URLs, labels and ids. Equal values have the same placeholder,
/// so that text that Markdown compares, such as the label of a reference link
/// and of its definition, is still equal.
class _Placeholders {
  final List<String> _values = [];
  final Map<String, int> _indexes = {};

  final String _key = _randomLetters();
  final String _autolinkKey = '${_random.nextInt(10)}${_randomLetters()}';

  late final RegExp _pattern = RegExp(
    '$_key'
    r'(\d+)'
    '$_key|$_autolinkKey'
    r'(\d+)'
    '$_autolinkKey',
  );

  static String _randomLetters() => String.fromCharCodes([
    for (var i = 0; i < 8; i++) 0x61 + _random.nextInt(26),
  ]);

  bool get isNotEmpty => _values.isNotEmpty;

  /// Returns the placeholder for [value], for a value in `<>` if [autolink].
  String add(String value, {bool autolink = false}) {
    var index = _indexes.putIfAbsent(value, () {
      _values.add(value);
      return _values.length - 1;
    });
    var key = autolink ? _autolinkKey : _key;
    return '$key$index$key';
  }

  String _value(Match m) => _values[int.parse(m[1] ?? m[2]!)];

  /// [extensionSet], with its syntaxes that generate the ids of headings
  /// replaced by ones that generate them from the Markdown of the heading with
  /// the values, as for the Markdown that has them. Subclasses of them, which
  /// may generate ids differently, are kept, and [fill] puts the values into
  /// the ids they generate.
  ///
  /// It also has [_PlaceholderAutolinkSyntax] first, which renders a
  /// placeholder in `<>` as Markdown would render the value in `<>`.
  ExtensionSet extensionSetFor(ExtensionSet extensionSet) => ExtensionSet(
    [
      for (var syntax in extensionSet.blockSyntaxes)
        if (syntax.runtimeType == HeaderWithIdSyntax)
          _HeaderWithIdSyntax(this)
        else if (syntax.runtimeType == SetextHeaderWithIdSyntax)
          _SetextHeaderWithIdSyntax(this)
        else
          syntax,
    ],
    [_PlaceholderAutolinkSyntax(this), ...extensionSet.inlineSyntaxes],
  );

  /// Generates the id of [heading] again, as [BlockSyntax.generateAnchorHash]
  /// does from its Markdown, which it still has, with the values.
  Element _generateId(Element heading) {
    var children = heading.children;
    if (heading.generatedId != null && children != null) {
      var markdown = children.first.textContent.replaceAllMapped(
        _pattern,
        _value,
      );
      heading.generatedId = BlockSyntax.generateAnchorHash(
        Element('h1', [Text(markdown)]),
      );
    }
    return heading;
  }

  /// Replaces the placeholders in the attributes of [nodes] with their values,
  /// HTML-escaped: in the URLs of `href` and `src` attributes as [_fillUrl]
  /// does, and in `id` attributes, such as those of footnotes, percent-encoded
  /// as in the URLs that link to them.
  ///
  /// The ids that other syntaxes generated for headings have the placeholders
  /// as [BlockSyntax.generateAnchorHash] left them, which are replaced with
  /// what the values would add to the id.
  void fill(List<Node> nodes) {
    for (var node in nodes) {
      // The text of nodes is filled once it is rendered, by [fillHtml].
      if (node is Element) {
        node.attributes.updateAll(
          (name, value) => _urlAttributes.contains(name)
              ? _fillUrl(value)
              : _fillText(value, encode: name == 'id'),
        );
        var children = node.children;
        if (children != null) fill(children);
        var id = node.generatedId;
        if (id != null && _pattern.hasMatch(id)) {
          node.generatedId = id.replaceAllMapped(
            _pattern,
            (m) =>
                _value(m)
                    .toLowerCase()
                    .replaceAll(_anchorUnsafe, '')
                    .replaceAll(_whitespace, '-'),
          );
        }
      }
    }
  }

  String _fillText(String text, {bool encode = false}) =>
      text.replaceAllMapped(_pattern, (m) {
        var value = _value(m);
        if (encode) value = Uri.encodeComponent(_withoutLoneSurrogates(value));
        return _htmlEscape.convert(value);
      });

  /// Replaces the placeholders left in [html], the rendered Markdown, which
  /// are those of text nodes, some of which are raw HTML. [_HtmlScanner] reads
  /// it as the browser does, also across nodes (as for a tag that a blank line
  /// splits) and the values put into it. Values are HTML-escaped in content,
  /// quoted attribute values and comments. Elsewhere, such as in a tag outside
  /// quotes (e.g. `<img src={{x}}>`), in `<textarea>` or `<style>`, or after
  /// `<script>`, `<svg>` or `<math>`, each of their characters, also letters
  /// and digits, is encoded as a character reference, so that they cannot be
  /// or end the name of a tag or attribute, an attribute value or a comment.
  String fillHtml(String html) {
    var scanner = _HtmlScanner();
    var filled = StringBuffer();
    void write(String text) {
      scanner.scan(text);
      filled.write(text);
    }

    var last = 0;
    for (var m in _pattern.allMatches(html)) {
      write(html.substring(last, m.start));
      var value = _value(m);
      write(
        scanner.inText
            ? _htmlEscape.convert(value)
            : value.replaceAllMapped(
                _character,
                (m) => '&#${m[0]!.runes.first};',
              ),
      );
      last = m.end;
    }
    write(html.substring(last));
    return filled.toString();
  }

  /// Puts the values into [url], percent-encoded: a value that starts it as a
  /// URL, and other values as a component of it. The URL is replaced with `#`
  /// when values make its scheme, unless it is one of [_safeSchemes]; a scheme
  /// that only the text of the view makes is kept.
  String _fillUrl(String url) {
    if (!_pattern.hasMatch(url)) return url;

    // The URL with the values encoded, which the text of the URL around them
    // already is, and where each non-empty value is in it.
    var filled = StringBuffer();
    var escaped = StringBuffer();
    var valueStarts = <int>[];
    var last = 0;
    for (var m in _pattern.allMatches(url)) {
      var text = url.substring(last, m.start);
      filled.write(text);
      escaped.write(text);

      var value = _withoutLoneSurrogates(_value(m));
      value = m.start == 0
          ? value.replaceAllMapped(
              _unsafeUrlCharacters,
              (m) => Uri.encodeComponent(m[0]!),
            )
          : Uri.encodeComponent(value);
      if (value.isNotEmpty) valueStarts.add(filled.length);
      filled.write(value);
      escaped.write(_htmlEscape.convert(value));
      last = m.end;
    }
    filled.write(url.substring(last));
    escaped.write(url.substring(last));

    var scheme = _scheme.firstMatch(filled.toString());
    if (scheme != null &&
        !_safeSchemes.contains(scheme[1]!.toLowerCase()) &&
        valueStarts.any((start) => start < scheme.end)) {
      return '#';
    }

    return escaped.toString();
  }
}

/// Reads HTML as the tokenizer of the browser does, as far as needed to know
/// where [_Placeholders.fillHtml] puts each value.
///
/// After a start tag in [_untrackedElements], which it cannot follow, it stays
/// in [_HtmlState.untracked], where values are encoded as in a tag.
class _HtmlScanner {
  var _state = _HtmlState.data;

  /// The name of the tag being read, in lowercase, and whether it is an end
  /// tag.
  final _tagName = StringBuffer();
  var _endTag = false;

  /// The element whose text is being read, in [_HtmlState.text].
  var _textElement = '';

  /// Whether a value is read as text here when it is HTML-escaped.
  bool get inText => const {
    _HtmlState.data,
    _HtmlState.doubleQuoted,
    _HtmlState.singleQuoted,
    _HtmlState.comment,
  }.contains(_state);

  void scan(String html) {
    for (var c in html.codeUnits) {
      _consume(c);
    }
  }

  void _consume(int c) {
    switch (_state) {
      case _HtmlState.data:
        if (c == _lt) _state = _HtmlState.tagOpen;
      case _HtmlState.tagOpen:
        if (c == _bang) {
          _state = _HtmlState.markupDeclarationOpen;
        } else if (c == _slash) {
          _state = _HtmlState.endTagOpen;
        } else if (_isLetter(c)) {
          _startTag(c, endTag: false);
        } else if (c == _question) {
          _state = _HtmlState.bogusComment;
        } else {
          _reconsume(_HtmlState.data, c);
        }
      case _HtmlState.endTagOpen:
        if (_isLetter(c)) {
          _startTag(c, endTag: true);
        } else if (c == _gt) {
          _state = _HtmlState.data;
        } else {
          _state = _HtmlState.bogusComment;
        }
      case _HtmlState.tagName:
        if (_isSpace(c)) {
          _state = _HtmlState.beforeAttributeName;
        } else if (c == _slash) {
          _state = _HtmlState.selfClosingStartTag;
        } else if (c == _gt) {
          _emitTag();
        } else {
          _tagName.writeCharCode(_toLower(c));
        }
      case _HtmlState.beforeAttributeName:
        if (c == _slash || c == _gt) {
          _reconsume(_HtmlState.afterAttributeName, c);
        } else if (!_isSpace(c)) {
          // Also `=`, which then starts the name.
          _state = _HtmlState.attributeName;
        }
      case _HtmlState.attributeName:
        if (_isSpace(c) || c == _slash || c == _gt) {
          _reconsume(_HtmlState.afterAttributeName, c);
        } else if (c == _equals) {
          _state = _HtmlState.beforeAttributeValue;
        }
      case _HtmlState.afterAttributeName:
        if (c == _slash) {
          _state = _HtmlState.selfClosingStartTag;
        } else if (c == _equals) {
          _state = _HtmlState.beforeAttributeValue;
        } else if (c == _gt) {
          _emitTag();
        } else if (!_isSpace(c)) {
          _state = _HtmlState.attributeName;
        }
      case _HtmlState.beforeAttributeValue:
        // A quote opens the value also after whitespace, as in `a= "b"`.
        if (c == _quot) {
          _state = _HtmlState.doubleQuoted;
        } else if (c == _apos) {
          _state = _HtmlState.singleQuoted;
        } else if (c == _gt) {
          _emitTag();
        } else if (!_isSpace(c)) {
          _state = _HtmlState.unquoted;
        }
      case _HtmlState.doubleQuoted:
        if (c == _quot) _state = _HtmlState.afterAttributeValueQuoted;
      case _HtmlState.singleQuoted:
        if (c == _apos) _state = _HtmlState.afterAttributeValueQuoted;
      case _HtmlState.unquoted:
        if (_isSpace(c)) {
          _state = _HtmlState.beforeAttributeName;
        } else if (c == _gt) {
          _emitTag();
        }
      case _HtmlState.afterAttributeValueQuoted:
        if (_isSpace(c)) {
          _state = _HtmlState.beforeAttributeName;
        } else if (c == _slash) {
          _state = _HtmlState.selfClosingStartTag;
        } else if (c == _gt) {
          _emitTag();
        } else {
          _reconsume(_HtmlState.beforeAttributeName, c);
        }
      case _HtmlState.selfClosingStartTag:
        if (c == _gt) {
          _emitTag();
        } else {
          _reconsume(_HtmlState.beforeAttributeName, c);
        }
      case _HtmlState.markupDeclarationOpen:
        // `<!--` starts a comment. Anything else, such as `<!DOCTYPE`, and
        // `<![CDATA[` outside `<svg>` and `<math>`, ends at the next `>`.
        if (c == _dash) {
          _state = _HtmlState.markupDeclarationDash;
        } else {
          _reconsume(_HtmlState.bogusComment, c);
        }
      case _HtmlState.markupDeclarationDash:
        if (c == _dash) {
          _state = _HtmlState.commentStart;
        } else {
          _reconsume(_HtmlState.bogusComment, c);
        }
      case _HtmlState.bogusComment:
        if (c == _gt) _state = _HtmlState.data;
      case _HtmlState.commentStart:
        if (c == _dash) {
          _state = _HtmlState.commentStartDash;
        } else if (c == _gt) {
          // `<!-->`
          _state = _HtmlState.data;
        } else {
          _reconsume(_HtmlState.comment, c);
        }
      case _HtmlState.commentStartDash:
        if (c == _dash) {
          _state = _HtmlState.commentEnd;
        } else if (c == _gt) {
          // `<!--->`
          _state = _HtmlState.data;
        } else {
          _reconsume(_HtmlState.comment, c);
        }
      case _HtmlState.comment:
        if (c == _dash) _state = _HtmlState.commentEndDash;
      case _HtmlState.commentEndDash:
        if (c == _dash) {
          _state = _HtmlState.commentEnd;
        } else {
          _reconsume(_HtmlState.comment, c);
        }
      case _HtmlState.commentEnd:
        // A comment ends at `-->`, and also at `--!>`.
        if (c == _gt) {
          _state = _HtmlState.data;
        } else if (c == _bang) {
          _state = _HtmlState.commentEndBang;
        } else if (c != _dash) {
          _reconsume(_HtmlState.comment, c);
        }
      case _HtmlState.commentEndBang:
        if (c == _dash) {
          _state = _HtmlState.commentEndDash;
        } else if (c == _gt) {
          _state = _HtmlState.data;
        } else {
          _reconsume(_HtmlState.comment, c);
        }
      case _HtmlState.text:
        if (c == _lt) _state = _HtmlState.textLessThan;
      case _HtmlState.textLessThan:
        if (c == _slash) {
          _tagName.clear();
          _state = _HtmlState.textEndTagOpen;
        } else {
          _reconsume(_HtmlState.text, c);
        }
      case _HtmlState.textEndTagOpen:
        _reconsume(
          _isLetter(c) ? _HtmlState.textEndTagName : _HtmlState.text,
          c,
        );
      case _HtmlState.textEndTagName:
        if (_isLetter(c)) {
          _tagName.writeCharCode(_toLower(c));
        } else if ((_isSpace(c) || c == _slash || c == _gt) &&
            _tagName.toString() == _textElement) {
          // Only the end tag of the element ends its text.
          _endTag = true;
          _reconsume(_HtmlState.tagName, c);
        } else {
          _reconsume(_HtmlState.text, c);
        }
      case _HtmlState.untracked:
        break;
    }
  }

  void _reconsume(_HtmlState state, int c) {
    _state = state;
    _consume(c);
  }

  void _startTag(int c, {required bool endTag}) {
    _tagName.clear();
    _endTag = endTag;
    _reconsume(_HtmlState.tagName, c);
  }

  /// Ends the tag at `>`, after which some elements have text, not tags.
  void _emitTag() {
    var name = _tagName.toString();
    if (_endTag) {
      _state = _HtmlState.data;
    } else if (_untrackedElements.contains(name)) {
      _state = _HtmlState.untracked;
    } else if (_textElements.contains(name)) {
      _textElement = name;
      _state = _HtmlState.text;
    } else {
      _state = _HtmlState.data;
    }
  }

  static const _bang = 0x21, _quot = 0x22, _apos = 0x27, _dash = 0x2D;
  static const _slash = 0x2F, _lt = 0x3C, _equals = 0x3D, _gt = 0x3E;
  static const _question = 0x3F;

  static bool _isSpace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0C || c == 0x0D;

  static bool _isLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

  static int _toLower(int c) => c >= 0x41 && c <= 0x5A ? c + 0x20 : c;
}

/// The states of the tokenizer of the browser that [_HtmlScanner] tells apart.
enum _HtmlState {
  data,
  tagOpen,
  endTagOpen,
  tagName,
  beforeAttributeName,
  attributeName,
  afterAttributeName,
  beforeAttributeValue,
  doubleQuoted,
  singleQuoted,
  unquoted,
  afterAttributeValueQuoted,
  selfClosingStartTag,
  markupDeclarationOpen,
  markupDeclarationDash,
  bogusComment,
  commentStart,
  commentStartDash,
  comment,
  commentEndDash,
  commentEnd,
  commentEndBang,

  /// The text of an element in [_textElements], up to its end tag.
  text,
  textLessThan,
  textEndTagOpen,
  textEndTagName,

  /// After a start tag in [_untrackedElements].
  untracked,
}

/// Renders a placeholder in `<>` as an autolink when its value is the URL or
/// email address of one, as for the Markdown with the value, and else as the
/// value in `<>` as text.
class _PlaceholderAutolinkSyntax extends InlineSyntax {
  final _Placeholders _placeholders;

  _PlaceholderAutolinkSyntax(this._placeholders)
    : super(
        '<(${_placeholders._autolinkKey}'
        r'(\d+)'
        '${_placeholders._autolinkKey})>',
        startCharacter: 0x3C,
      );

  @override
  bool onMatch(InlineParser parser, Match match) {
    var placeholder = match[1]!;
    var value = _placeholders._values[int.parse(match[2]!)];
    if (_autolinkUrl.hasMatch(value)) {
      parser.addNode(
        Element.text('a', placeholder)..attributes['href'] = placeholder,
      );
    } else if (_autolinkEmail.hasMatch(value)) {
      parser.addNode(
        Element.text('a', placeholder)
          ..attributes['href'] = _placeholders.add('mailto:$value'),
      );
    } else {
      parser.addNode(Text('&lt;$placeholder&gt;'));
    }
    return true;
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
      // Tears off toJson before calling it, so that a NoSuchMethodError
      // thrown inside it, such as for another object without toJson(), is
      // passed on, and is not reported as a missing toJson().
      Object? toJson;
      try {
        toJson = (target as dynamic).toJson;
      } on NoSuchMethodError {
        toJson = null;
      }
      if (toJson is! Object? Function()) {
        throw ArgumentError(
          'Cannot read "$name" of "${path()}", a ${target.runtimeType}. '
          'Locals must be Maps, or have a toJson() method that returns one.',
        );
      }
      return toJson();
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
