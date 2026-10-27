import 'dart:async';
import 'dart:convert' show HtmlEscape, HtmlEscapeMode;
import 'dart:math' show max, min;

import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:belatuk_range_header/belatuk_range_header.dart';

final RegExp _param = RegExp(r':([A-Za-z0-9_]+)(\((.+)\))?');
final RegExp _straySlashes = RegExp(r'(^/+)|(/+$)');

const HtmlEscape _escapeText = HtmlEscape(HtmlEscapeMode.element);
const HtmlEscape _escapeAttribute = HtmlEscape(HtmlEscapeMode.attribute);

String _pathify(String path) {
  var p = path.replaceAll(_straySlashes, '');

  var replace = {};

  for (Match match in _param.allMatches(p)) {
    if (match[3] != null) replace[match[0]] = ':${match[1]}';
  }

  replace.forEach((k, v) {
    if (k is String && v is String) {
      p = p.replaceAll(k, v);
    }
  });

  return p;
}

/// A static server plug-in.
class VirtualDirectory {
  final _log = Logger('VirtualDirectory');

  late String _prefix;
  late Directory _source;

  /// The directory to serve files from.
  Directory get source => _source;

  /// An optional callback to run before serving files.
  final Function(File file, RequestContext req, ResponseContext res)? callback;

  final Angel app;
  final FileSystem fileSystem;

  /// Filenames to be resolved within directories as indices.
  final Iterable<String> indexFileNames;

  /// An optional public path to map requests to.
  final String publicPath;

  /// If `true` (default: `false`), then if a directory does not contain any of the specific [indexFileNames], a default directory listing will be served.
  final bool allowDirectoryListing;

  /// If `true` (default: `true`), then files will be opened as streams and piped into the request.
  ///
  /// If not, the response buffer will be used instead.
  final bool useBuffer;

  /// If `true` (default: `false`), a symbolic link in [source] to a file or
  /// directory outside of it is followed. Otherwise such a path is not
  /// served, as if it did not exist.
  final bool followLinksOutsideSource;

  VirtualDirectory(
    this.app,
    this.fileSystem, {
    Directory? source,
    this.indexFileNames = const ['index.html'],
    this.publicPath = '/',
    this.callback,
    this.allowDirectoryListing = false,
    this.useBuffer = false,
    this.followLinksOutsideSource = false,
  }) {
    _prefix = publicPath.replaceAll(_straySlashes, '');
    if (source != null) {
      _source = source;
    } else {
      var dirPath = app.environment.isProduction ? './build/web' : './web';
      _source = fileSystem.directory(dirPath);
    }
  }

  /// Whether [path], without its leading and trailing slashes, is in the
  /// [publicPath]: the same path, or one under it, segment by segment.
  bool _isUnderPrefix(String path) =>
      _prefix.isEmpty || path == _prefix || path.startsWith('$_prefix/');

  /// Responds to incoming HTTP requests.
  Future<bool> handleRequest(RequestContext req, ResponseContext res) {
    if (req.method != 'GET' && req.method != 'HEAD') {
      return Future<bool>.value(true);
    }
    var path = req.uri!.path.replaceAll(_straySlashes, '');

    if (!_isUnderPrefix(path)) {
      return Future<bool>.value(true);
    }

    return servePath(path, req, res);
  }

  /// A handler that serves the file at the given path, unless the user has requested that path.
  ///
  /// You can also limit this functionality to specific values of the `Accept` header, ex. `text/html`.
  /// If [accepts] is `null`, OR at least one of the content types in [accepts] is present,
  /// the view will be served.
  RequestHandler pushState(String path, {Iterable? accepts}) {
    var vPath = path.replaceAll(_straySlashes, '');
    if (_prefix.isNotEmpty == true) vPath = '$_prefix/$vPath';

    return (RequestContext req, ResponseContext res) {
      var path = req.path.replaceAll(_straySlashes, '');
      if (path == vPath) return Future<bool>.value(true);

      if (accepts?.isNotEmpty == true) {
        if (!accepts!.any((x) => req.accepts(x, strict: true))) {
          return Future<bool>.value(true);
        }
      }

      return servePath(vPath, req, res);
    };
  }

  /// Writes the file at the given virtual [path] to a response.
  ///
  /// A path that is not in [source], including through a symbolic link
  /// unless [followLinksOutsideSource], is not served: the request goes on,
  /// as for a path that does not exist.
  Future<bool> servePath(
    String path,
    RequestContext req,
    ResponseContext res,
  ) async {
    if (_prefix.isNotEmpty) {
      // Only replace the *first* incidence, of a whole segment.
      // Resolve: https://github.com/angel-dart/angel/issues/41
      path = path.replaceFirst(RegExp('^${_pathify(_prefix)}(?=/|\$)'), '');
    }

    if (path.isEmpty) path = '.';
    path = path.replaceAll(_straySlashes, '');

    String absolute, parent;
    try {
      absolute = source.absolute.uri.resolve(path).toFilePath();
      parent = source.absolute.uri.toFilePath();
    } on UnsupportedError {
      // A path that cannot be a file path here, e.g. with an (encoded)
      // backslash on Windows.
      return true;
    }

    if (!p.isWithin(parent, absolute) && !p.equals(parent, absolute)) {
      return true;
    }

    // Update to the correct file separator based on file system
    if (absolute.contains('\\') && fileSystem.path.separator == '/') {
      absolute = absolute.replaceAll('\\', '/');
      _log.warning(
        'Incompatible file system type is used. Changed file separator from "\\" to "/".',
      );
    } else if (absolute.contains('/') && fileSystem.path.separator == '\\') {
      absolute = absolute.replaceAll('/', '\\');
      _log.warning(
        'Incompatible file system type. Changed file separator from "/" to "\\".',
      );
    }

    // `stat` follows symbolic links: one may lead out of the source.
    if (!followLinksOutsideSource && !await _resolvesInSource(absolute)) {
      return true;
    }

    var stat = await fileSystem.stat(absolute);
    return await serveStat(absolute, path, stat, req, res);
  }

  /// The [source], with its symbolic links resolved.
  Future<String>? _realSource;

  /// Whether [absolute], with its symbolic links resolved, is in [source],
  /// or does not exist.
  Future<bool> _resolvesInSource(String absolute) async {
    String real, root;
    try {
      real = await fileSystem.file(absolute).resolveSymbolicLinks();
    } on FileSystemException {
      // It does not exist, which serveStat handles.
      return true;
    }
    try {
      root = await (_realSource ??= source.resolveSymbolicLinks());
    } on FileSystemException {
      return false;
    }
    return p.equals(root, real) || p.isWithin(root, real);
  }

  /// Writes the file at the path given by the [stat] to a response.
  Future<bool> serveStat(
    String absolute,
    String relative,
    FileStat stat,
    RequestContext req,
    ResponseContext res,
  ) async {
    if (stat.type == FileSystemEntityType.directory) {
      return await serveDirectory(
        fileSystem.directory(absolute),
        relative,
        stat,
        req,
        res,
      );
    } else if (stat.type == FileSystemEntityType.file) {
      return await serveFile(fileSystem.file(absolute), stat, req, res);
    } else {
      // Not found, or a link that leads nowhere (`stat` follows links).
      return true;
    }
  }

  /// Serves the index file of a [directory], if it exists.
  Future<bool> serveDirectory(
    Directory directory,
    String relative,
    FileStat stat,
    RequestContext req,
    ResponseContext res,
  ) async {
    for (var indexFileName in indexFileNames) {
      final index = fileSystem.file(
        directory.absolute.uri.resolve(indexFileName),
      );
      if (await index.exists()) {
        // Of the index file itself, whose changes its directory's
        // modification time does not show.
        return await serveFile(index, await index.stat(), req, res);
      }
    }

    if (allowDirectoryListing == true) {
      res.contentType = MediaType('text', 'html', {'charset': 'utf-8'});
      res
        ..write('<!DOCTYPE html>')
        ..write('<html>')
        ..write(
          '<head><meta name="viewport" content="width=device-width,initial-scale=1">',
        )
        ..write('<style>ul { list-style-type: none; }</style>')
        ..write('</head><body><ul>');

      res.write('<li><a href="..">..</a></li>');

      var entities = await directory
          .list(followLinks: false)
          .toList()
          .then((l) => List.from(l));
      entities.sort((a, b) {
        if (a is Directory) {
          if (b is Directory) {
            return a.path.compareTo(b.path);
          }
          return -1;
        } else if (a is File) {
          if (b is Directory) {
            return 1;
          } else if (b is File) {
            return a.path.compareTo(b.path);
          }
          return -1;
        } else if (a is Link) {
          if (b is Directory) {
            return 1;
          } else if (b is Link) {
            return a.path.compareTo(b.path);
          }
          return -1;
        }

        return 1;
      });

      for (var entity in entities) {
        String stub;
        String type;

        if (entity is File) {
          type = '[File]';
          stub = p.basename(entity.path);
        } else if (entity is Directory) {
          type = '[Directory]';
          stub = p.basename(entity.path);
        } else if (entity is Link) {
          type = '[Link]';
          stub = p.basename(entity.path);
        } else {
          _log.severe('Unknown file entity. Not a file, directory or link.');
          type = '[]';
          stub = '';
        }
        var href = stub;

        if (relative.isNotEmpty) {
          href = '/$relative/$stub';
        }

        if (entity is Directory) {
          if (href == '') {
            href = '/';
          } else {
            href += '/';
          }
        }
        // A name may hold markup, so it is escaped, as text and as an
        // attribute.
        href = _escapeAttribute.convert(Uri.encodeFull(href));

        res.write(
          '<li><a href="$href">$type ${_escapeText.convert(stub)}</a></li>',
        );
      }

      res.write('</ul></body></html>');
      return false;
    }

    return true;
  }

  void _ensureContentTypeAllowed(String mimeType, RequestContext req) {
    if (!req.accepts(mimeType)) {
      var value = req.headers?.value('accept');
      _log.fine('Accept [$value] does not allow $mimeType');
      throw AngelHttpException(
        errors: [
          'Client requested $value, but server wanted to send $mimeType.',
        ],
        statusCode: 406,
        message: '406 Not Acceptable',
      );
    }
  }

  /// Writes the contents of a file to a response.
  ///
  /// Override this to change how a file is served; [sendFile] writes it.
  Future<bool> serveFile(
    File file,
    FileStat stat,
    RequestContext req,
    ResponseContext res,
  ) => sendFile(file, stat, req, res);

  /// Writes the contents of a file to a response, as [serveFile] does: of
  /// the request's `Range`, unless [ignoreRange], as for an `If-Range` that
  /// no longer matches the file.
  @protected
  Future<bool> sendFile(
    File file,
    FileStat stat,
    RequestContext req,
    ResponseContext res, {
    bool ignoreRange = false,
  }) async {
    res.headers['accept-ranges'] = 'bytes';

    if (callback != null) {
      return await req.app?.executeHandler(
            (RequestContext req, ResponseContext res) =>
                callback!(file, req, res),
            req,
            res,
          ) ??
          true;
    }

    var type =
        app.mimeTypeResolver.lookup(file.path) ?? 'application/octet-stream';
    _ensureContentTypeAllowed(type, req);
    res.contentType = MediaType.parse(type);
    if (useBuffer == true) res.useBuffer();

    if (req.headers == null) {
      _log.severe('Missing headers in the RequestContext');
      throw ArgumentError('Missing headers in the RequestContext');
    }
    var range = req.headers!.value('range');

    if (ignoreRange || range?.startsWith('bytes=') != true) {
      await res.streamFile(file);
      return false;
    }

    var totalFileSize = await file.length();
    RangeHeader header;
    try {
      header = RangeHeader.parse(range!);
    } on RangeHeaderParseException {
      // Such as an end before its start, which the parser refuses.
      throw _invalidRange();
    }
    var items = _satisfiable(header, totalFileSize);

    if (items.isEmpty) {
      res.headers['content-range'] = 'bytes */$totalFileSize';
      throw AngelHttpException(
        statusCode: 416,
        message: 'No range of `$range` is in the $totalFileSize bytes.',
      );
    }

    // The framework does not encode a 206, whose ranges are of these bytes.
    res.statusCode = 206;

    if (items.length == 1) {
      var (from, to) = items.single;
      res.headers['content-length'] = (to - from + 1).toString();
      res.headers['content-range'] = 'bytes $from-$to/$totalFileSize';
      await file.openRead(from, to + 1).cast<List<int>>().pipe(res);
      return false;
    }

    var transformer = RangeHeaderTransformer(
      RangeHeader([for (var (from, to) in items) RangeHeaderItem(from, to)]),
      type,
      totalFileSize,
    );
    res.headers['content-length'] = transformer
        .computeContentLength(totalFileSize)
        .toString();
    res.contentType = MediaType('multipart', 'byteranges', {
      'boundary': transformer.boundary,
    });
    await file.openRead().cast<List<int>>().transform(transformer).pipe(res);
    return false;
  }

  /// The ranges of [header] in a file of [size] bytes, as inclusive
  /// `(from, to)` byte indices, in order and merged where they overlap or
  /// touch (RFC 9110).
  ///
  /// An end past the file is the file's end, and a suffix range (`-500`) is
  /// the last bytes of the file. A range that starts past the file, or a
  /// suffix of no bytes, is left out. Throws a 416 for a range that is
  /// invalid (an end before its start).
  static List<(int, int)> _satisfiable(RangeHeader header, int size) {
    var ranges = <(int, int)>[];
    for (var item in header.items) {
      if (item.start == -1) {
        if (item.end == -1) throw _invalidRange();
        // A suffix of item.end bytes.
        if (item.end == 0 || size == 0) continue;
        ranges.add((max(0, size - item.end), size - 1));
      } else {
        if (item.end != -1 && item.end < item.start) throw _invalidRange();
        if (item.start >= size) continue;
        ranges.add((
          item.start,
          item.end == -1 ? size - 1 : min(item.end, size - 1),
        ));
      }
    }

    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    var merged = <(int, int)>[];
    for (var range in ranges) {
      if (merged.isNotEmpty && range.$1 <= merged.last.$2 + 1) {
        var last = merged.removeLast();
        merged.add((last.$1, max(last.$2, range.$2)));
      } else {
        merged.add(range);
      }
    }
    return merged;
  }

  static AngelHttpException _invalidRange() => AngelHttpException(
    errors: ['Semantically invalid, or unbounded range.'],
    statusCode: 416,
    message: 'Semantically invalid, or unbounded range.',
  );
}
