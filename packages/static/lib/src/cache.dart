import 'dart:async';
import 'dart:io' show HttpDate, HttpException, HttpHeaders;

import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';

import 'virtual_directory.dart';

/// A `VirtualDirectory` that also sets `Cache-Control` headers, and answers
/// conditional requests (`If-None-Match`, `If-Modified-Since`, `If-Range`)
/// from the file as it is when it is requested.
class CachingVirtualDirectory extends VirtualDirectory {
  /// Either `public` or `private`.
  final CacheAccessLevel accessLevel;

  /// If `true`, responses will always have `private, max-age=0` as their `Cache-Control` header.
  final bool noCache;

  /// If `true` (default), `Cache-Control` headers will only be set if the application is in production mode.
  final bool onlyInProduction;

  /// If `true` (default), ETags will be computed and sent along with responses.
  final bool useEtags;

  /// The `max-age` for `Cache-Control`, in seconds, and how far ahead the
  /// `Expires` header is.
  final int maxAge;

  CachingVirtualDirectory(
    super.app,
    super.fileSystem, {
    this.accessLevel = CacheAccessLevel.public,
    super.source,
    @Deprecated('Not used.') bool debug = false,
    super.indexFileNames,
    this.maxAge = 0,
    this.noCache = false,
    this.onlyInProduction = false,
    this.useEtags = true,
    super.allowDirectoryListing,
    super.useBuffer,
    super.publicPath,
    super.callback,
    super.followLinksOutsideSource,
  });

  /// The strong ETag of a file of [stat]: of its modification time and size,
  /// so it changes when the file does.
  static String etagOf(FileStat stat) =>
      '"${stat.modified.millisecondsSinceEpoch.toRadixString(16)}-'
      '${stat.size.toRadixString(16)}"';

  /// [time] to the second, as HTTP dates are.
  static DateTime _toSeconds(DateTime time) {
    var utc = time.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    );
  }

  /// The entity tags of the [name] headers, which may each list several.
  static List<String> _etagsOf(HttpHeaders headers, String name) => [
    for (var value in headers[name] ?? const <String>[])
      for (var tag in value.split(','))
        if (tag.trim().isNotEmpty) tag.trim(),
  ];

  /// Whether the entity tags [a] and [b] are the same, ignoring a weak `W/`
  /// prefix (the weak comparison of `If-None-Match`).
  static bool _weaklyEqual(String a, String b) =>
      a.replaceFirst('W/', '') == b.replaceFirst('W/', '');

  @override
  Future<bool> serveFile(
    File file,
    FileStat stat,
    RequestContext req,
    ResponseContext res,
  ) {
    res.headers['accept-ranges'] = 'bytes';

    if (onlyInProduction == true && req.app?.environment.isProduction != true) {
      return sendFile(file, stat, req, res);
    }

    var reqHeaders = req.headers;
    if (reqHeaders == null) {
      throw ArgumentError('Missing headers in the RequestContext');
    }

    var modified = _toSeconds(stat.modified);
    var etag = useEtags ? etagOf(stat) : null;

    if (noCache) {
      res.headers['cache-control'] = 'private, max-age=0, no-cache';
    } else {
      setCachedHeaders(modified, req, res);
    }
    if (etag != null) res.headers['etag'] = etag;

    // A client asking to revalidate (`Cache-Control: no-cache`) gets the
    // file, not a 304.
    var revalidate =
        (reqHeaders.value('cache-control') ?? '')
            .toLowerCase()
            .split(',')
            .any((d) => d.trim() == 'no-cache') ||
        reqHeaders.value('pragma')?.toLowerCase() == 'no-cache';

    if (!revalidate && _notModified(reqHeaders, modified, etag)) {
      res.statusCode = 304;
      return Future.value(false);
    }

    return sendFile(
      file,
      stat,
      req,
      res,
      ignoreRange: !_ifRangeMatches(reqHeaders, modified, etag),
    );
  }

  /// Whether the conditions of the request say that the client's copy is
  /// the file as it is: `If-None-Match`, or else, without it,
  /// `If-Modified-Since` (RFC 9110).
  bool _notModified(HttpHeaders headers, DateTime modified, String? etag) {
    var noneMatch = _etagsOf(headers, 'if-none-match');
    if (noneMatch.isNotEmpty) {
      return noneMatch.any(
        (tag) => tag == '*' || (etag != null && _weaklyEqual(tag, etag)),
      );
    }

    var since = headers.value('if-modified-since');
    if (since == null) return false;
    try {
      return !modified.isAfter(HttpDate.parse(since));
    } on FormatException {
      // An invalid date is ignored.
      return false;
    } on HttpException {
      return false;
    }
  }

  /// Whether the `Range` of the request applies: it has no `If-Range`, or
  /// its `If-Range` is the file's strong ETag or its exact `Last-Modified`.
  /// Otherwise the file has changed, and is sent whole.
  bool _ifRangeMatches(HttpHeaders headers, DateTime modified, String? etag) {
    var ifRange = headers.value('if-range')?.trim();
    if (ifRange == null || ifRange.isEmpty) return true;
    if (ifRange.startsWith('"') || ifRange.startsWith('W/')) {
      // A weak tag never matches (strong comparison).
      return etag != null && ifRange == etag;
    }
    try {
      return HttpDate.parse(ifRange).isAtSameMomentAs(modified);
    } on FormatException {
      return false;
    } on HttpException {
      return false;
    }
  }

  void setCachedHeaders(
    DateTime modified,
    RequestContext req,
    ResponseContext res,
  ) {
    var privacy = accessLevel.level;

    res.headers
      ..['cache-control'] = '$privacy, max-age=$maxAge'
      ..['last-modified'] = HttpDate.format(modified);

    var expiry = DateTime.now().add(Duration(seconds: maxAge));
    res.headers['expires'] = HttpDate.format(expiry);
  }
}

enum CacheAccessLevel {
  public('public'),
  private('private');

  const CacheAccessLevel(this.level);
  final String level;
}
