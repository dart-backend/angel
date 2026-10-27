import 'dart:async';
import 'dart:convert';
import 'dart:math' show max;

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

/// Inlines assets into buffered responses, resolving paths from an [assetDirectory].
///
/// In any `.html` file sent down, `link` and `script` elements that point to internal resources
/// will have the contents of said file read, and inlined into the HTML page itself.
///
/// In this case, "internal resources" refers to a URI *without* a scheme, i.e. `/site.css` or
/// `foo/bar/baz.js`, of a file in [assetDirectory]: `/site.css` and
/// `site.css` are both `site.css` of [assetDirectory], and a path out of it
/// (`../secret`) is not inlined. The response is sent as UTF-8.
RequestHandler inlineAssets(Directory assetDirectory) {
  return (req, res) async {
    if (!res.isOpen ||
        !res.isBuffered ||
        res.contentType.mimeType != 'text/html') {
      return true;
    }

    var charset = res.contentType.parameters['charset'];
    var encoding =
        (charset == null ? null : Encoding.getByName(charset)) ?? utf8;
    var bytes = res.buffer!.takeBytes();
    String source;
    try {
      source = encoding.decode(bytes);
    } on FormatException {
      // Not of its charset: sent as it is.
      res.buffer!.add(bytes);
      return true;
    }

    var doc = html.parse(source);
    await inlineAssetsIntoDocument(doc, assetDirectory);
    _declareUtf8(doc);
    res.contentType = MediaType('text', 'html', {'charset': 'utf-8'});
    res.buffer!.add(utf8.encode(doc.outerHtml));
    return false;
  };
}

/// Wraps a `VirtualDirectory` to patch the way it sends
/// `.html` files.
///
/// In any `.html` file sent down, `link` and `script` elements that point to internal resources
/// will have the contents of said file read, and inlined into the HTML page itself.
///
/// In this case, "internal resources" refers to a URI *without* a scheme, i.e. `/site.css` or
/// `foo/bar/baz.js`, of a file in the directory's source.
///
/// The page is then served by [vDir] as it serves any file, so its caching
/// headers (of a `CachingVirtualDirectory`), `Range` support and `callback`
/// apply. Its `Last-Modified` and ETag are of the latest of the page and the
/// assets inlined into it, so they change when an asset does.
VirtualDirectory inlineAssetsFromVirtualDirectory(VirtualDirectory vDir) =>
    _InlineAssets(vDir);

/// Replaces `link` and `script` tags within a [doc] with the static contents they would otherwise trigger an HTTP request to.
///
/// Powers both [inlineAssets] and [inlineAssetsFromVirtualDirectory].
///
/// An asset is a file of [assetDirectory]; a reference with a scheme or a
/// host, or to a path out of [assetDirectory], is left as it is, as are an
/// element marked `data-no-inline`, a `script` that is `async`, or `defer`
/// but not a module (an inline script runs at once), and an element whose
/// reference is missing or malformed. A stylesheet's `media` and `nonce` are
/// kept on its `style`.
///
/// Returns when the latest of the inlined files was modified, or `null` if
/// none was inlined.
Future<DateTime?> inlineAssetsIntoDocument(
  html.Document doc,
  Directory? assetDirectory,
) async {
  DateTime? latest;
  void touched(DateTime modified) {
    latest = latest == null || modified.isAfter(latest!) ? modified : latest;
  }

  var stylesheets = doc
      .getElementsByTagName('link')
      .where(_isStylesheet)
      .toList();

  for (var link in stylesheets) {
    if (link.attributes.containsKey('data-no-inline')) {
      link.attributes.remove('data-no-inline');
      continue;
    }
    if (assetDirectory == null) continue;
    var styleFile = _assetFile(assetDirectory, link.attributes['href']);
    if (styleFile == null || !await styleFile.exists()) continue;

    var style = html.Element.tag('style')
      ..text = _escapeClosing(await styleFile.readAsString(), 'style');
    for (var name in ['media', 'nonce']) {
      var value = link.attributes[name];
      if (value != null) style.attributes[name] = value;
    }
    touched(await styleFile.lastModified());
    link.replaceWith(style);
  }

  var scripts = doc
      .getElementsByTagName('script')
      .where((script) => script.attributes.containsKey('src'))
      .toList();

  for (var script in scripts) {
    if (script.attributes.containsKey('data-no-inline')) {
      script.attributes.remove('data-no-inline');
      continue;
    }
    if (assetDirectory == null || !_runsInline(script)) continue;
    var scriptFile = _assetFile(assetDirectory, script.attributes['src']);
    if (scriptFile == null || !await scriptFile.exists()) continue;

    script.attributes.remove('src');
    script.text = _escapeClosing(await scriptFile.readAsString(), 'script');
    touched(await scriptFile.lastModified());
  }

  return latest;
}

/// Whether [link] is a stylesheet, and not an alternate one.
bool _isStylesheet(html.Element link) {
  var rel = (link.attributes['rel'] ?? '').toLowerCase().split(RegExp(r'\s+'));
  return rel.contains('stylesheet') && !rel.contains('alternate');
}

/// Whether [script] runs the same once inlined: not `async`, nor `defer`
/// unless a module, which is deferred anyway.
bool _runsInline(html.Element script) {
  var attributes = script.attributes;
  if (attributes.containsKey('async')) return false;
  var module = attributes['type']?.trim().toLowerCase() == 'module';
  return module || !attributes.containsKey('defer');
}

/// [content] for a `<tag>` element, whose end tag, or a comment opening in a
/// script, it must not hold: `</script` becomes `<\/script`, valid in a
/// string or a regular expression, as is `<\!--` for `<!--`.
String _escapeClosing(String content, String tag) {
  var escaped = content.replaceAllMapped(
    RegExp('</($tag)', caseSensitive: false),
    (m) => '<\\/${m[1]}',
  );
  return tag == 'script' ? escaped.replaceAll('<!--', r'<\!--') : escaped;
}

/// The file of [assetDirectory] that [reference] names, or `null` if it is
/// missing or malformed, names another host, or a path out of
/// [assetDirectory]. A leading `/` is the root of [assetDirectory].
File? _assetFile(Directory assetDirectory, String? reference) {
  if (reference == null || reference.trim().isEmpty) return null;
  Uri uri;
  try {
    uri = Uri.parse(reference.trim());
  } on FormatException {
    return null;
  }
  if (uri.hasScheme || uri.hasAuthority) return null;

  List<String> decoded;
  try {
    decoded = uri.pathSegments;
  } on ArgumentError {
    return null;
  }

  var segments = <String>[];
  for (var segment in decoded) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isEmpty) return null;
      segments.removeLast();
    } else if (segment.contains('/') || segment.contains('\\')) {
      return null;
    } else {
      segments.add(segment);
    }
  }
  if (segments.isEmpty) return null;

  var fs = assetDirectory.fileSystem;
  var root = fs.path.normalize(assetDirectory.absolute.path);
  var file = fs.file(fs.path.joinAll([root, ...segments]));
  return fs.path.isWithin(root, fs.path.normalize(file.path)) ? file : null;
}

/// Makes the `<meta charset>` of [doc] UTF-8, as it is sent.
void _declareUtf8(html.Document doc) {
  for (var meta in doc.getElementsByTagName('meta')) {
    if (meta.attributes.containsKey('charset')) {
      meta.attributes['charset'] = 'utf-8';
      return;
    }
    if (meta.attributes['http-equiv']?.toLowerCase() == 'content-type') {
      meta.attributes['content'] = 'text/html; charset=utf-8';
      return;
    }
  }
  var head = doc.head;
  if (head != null) {
    var meta = html.Element.tag('meta')..attributes['charset'] = 'utf-8';
    head.insertBefore(meta, head.firstChild);
  }
}

class _InlineAssets extends VirtualDirectory {
  final VirtualDirectory inner;

  _InlineAssets(this.inner)
    : super(
        inner.app,
        inner.fileSystem,
        source: inner.source,
        indexFileNames: inner.indexFileNames,
        publicPath: inner.publicPath,
        callback: inner.callback,
        allowDirectoryListing: inner.allowDirectoryListing,
        useBuffer: inner.useBuffer,
        followLinksOutsideSource: inner.followLinksOutsideSource,
      );

  static final RegExp _html = RegExp(r'\.html?$', caseSensitive: false);

  @override
  Future<bool> serveFile(
    File file,
    FileStat stat,
    RequestContext req,
    ResponseContext res,
  ) async {
    if (!_html.hasMatch(file.path)) {
      return await inner.serveFile(file, stat, req, res);
    }

    var bytes = await file.readAsBytes();
    String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException {
      source = latin1.decode(bytes);
    }
    var doc = html.parse(source, sourceUrl: file.uri.toString());
    var assetsModified = await inlineAssetsIntoDocument(doc, inner.source);
    _declareUtf8(doc);
    var inlined = utf8.encode(doc.outerHtml);

    // Served by [inner] as a file of its own, of the same name, so that its
    // headers, caching and ranges apply to the inlined page.
    var page = MemoryFileSystem().file('/${p.basename(file.path)}')
      ..writeAsBytesSync(inlined);
    var modified = assetsModified == null
        ? stat.modified
        : DateTime.fromMillisecondsSinceEpoch(
            max(
              stat.modified.millisecondsSinceEpoch,
              assetsModified.millisecondsSinceEpoch,
            ),
          );
    return await inner.serveFile(
      page,
      _InlinedStat(stat, modified, inlined.length),
      req,
      res,
    );
  }
}

/// The [FileStat] of an inlined page: of its size, and of the latest of the
/// page and its assets.
class _InlinedStat implements FileStat {
  final FileStat _page;

  @override
  final DateTime modified;

  @override
  final int size;

  _InlinedStat(this._page, this.modified, this.size);

  @override
  DateTime get changed => modified;

  @override
  DateTime get accessed => _page.accessed;

  @override
  FileSystemEntityType get type => _page.type;

  @override
  int get mode => _page.mode;

  @override
  String modeString() => _page.modeString();
}
