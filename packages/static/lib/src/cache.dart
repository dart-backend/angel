import 'dart:async';
import 'dart:io' show HttpDate;
import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';
import 'package:logging/logging.dart';
import 'virtual_directory.dart';

/// A `VirtualDirectory` that also sets `Cache-Control` headers.
class CachingVirtualDirectory extends VirtualDirectory {
  final _log = Logger('CachingVirtualDirectory');

  final Map<String, String> _etags = {};

  /// Either `public` or `private`.
  final CacheAccessLevel accessLevel;

  /// If `true`, responses will always have `private, max-age=0` as their `Cache-Control` header.
  final bool noCache;

  /// If `true` (default), `Cache-Control` headers will only be set if the application is in production mode.
  final bool onlyInProduction;

  /// If `true` (default), ETags will be computed and sent along with responses.
  final bool useEtags;

  /// The `max-age` for `Cache-Control`.
  ///
  /// Set this to `null` to leave no `Expires` header on responses.
  final int maxAge;

  CachingVirtualDirectory(
    super.app,
    super.fileSystem, {
    this.accessLevel = CacheAccessLevel.public,
    super.source,
    bool debug = false,
    super.indexFileNames,
    this.maxAge = 0,
    this.noCache = false,
    this.onlyInProduction = false,
    this.useEtags = true,
    super.allowDirectoryListing,
    super.useBuffer,
    super.publicPath,
    super.callback,
  });

  @override
  Future<bool> serveFile(
    File file,
    FileStat stat,
    RequestContext req,
    ResponseContext res,
  ) {
    res.headers['accept-ranges'] = 'bytes';

    if (onlyInProduction == true && req.app?.environment.isProduction != true) {
      return super.serveFile(file, stat, req, res);
    }

    if (req.headers == null) {
      _log.severe('Missing headers in the RequestContext');
      throw ArgumentError('Missing headers in the RequestContext');
    }
    var reqHeaders = req.headers!;

    var shouldNotCache = noCache == true;

    if (!shouldNotCache) {
      shouldNotCache =
          reqHeaders.value('cache-control') == 'no-cache' ||
          reqHeaders.value('pragma') == 'no-cache';
    }

    if (shouldNotCache) {
      res.headers['cache-control'] = 'private, max-age=0, no-cache';
      return super.serveFile(file, stat, req, res);
    } else {
      var ifModified = reqHeaders.ifModifiedSince;
      var ifRange = false;

      try {
        if (reqHeaders.value('if-range') != null) {
          ifModified = HttpDate.parse(reqHeaders.value('if-range')!);
          ifRange = true;
        }
      } catch (_) {
        // Fail silently...
      }

      if (ifModified != null) {
        try {
          var ifModifiedSince = ifModified;

          if (ifModifiedSince.compareTo(stat.modified) >= 0) {
            res.statusCode = 304;
            setCachedHeaders(stat.modified, req, res);

            if (useEtags && _etags.containsKey(file.absolute.path)) {
              if (_etags[file.absolute.path] != null) {
                res.headers['ETag'] = _etags[file.absolute.path]!;
              }
            }

            if (ifRange) {
              // Send the 206 like normal
              res.statusCode = 206;
              return super.serveFile(file, stat, req, res);
            }

            return Future.value(false);
          } else if (ifRange) {
            return super.serveFile(file, stat, req, res);
          }
        } catch (_) {
          _log.severe(
            'Invalid date for ${ifRange ? 'if-range' : 'if-not-modified-since'} header.',
          );
          throw AngelHttpException.badRequest(
            message:
                'Invalid date for ${ifRange ? 'if-range' : 'if-not-modified-since'} header.',
          );
        }
      }

      // If-modified didn't work; try etags

      if (useEtags == true) {
        var etagsToMatchAgainst = reqHeaders['if-none-match'] ?? [];
        ifRange = false;

        if (etagsToMatchAgainst.isEmpty) {
          etagsToMatchAgainst = reqHeaders['if-range'] ?? [];
          ifRange = etagsToMatchAgainst.isNotEmpty;
        }

        if (etagsToMatchAgainst.isNotEmpty) {
          var hasBeenModified = false;

          for (var etag in etagsToMatchAgainst) {
            if (etag == '*') {
              hasBeenModified = true;
            } else {
              hasBeenModified =
                  !_etags.containsKey(file.absolute.path) ||
                  _etags[file.absolute.path] != etag;
            }
          }

          if (!ifRange) {
            if (!hasBeenModified) {
              res.statusCode = 304;
              setCachedHeaders(stat.modified, req, res);
              return Future.value(false);
            }
          } else {
            return super.serveFile(file, stat, req, res);
          }
        }
      }

      return file.lastModified().then((stamp) {
        if (useEtags) {
          res.headers['ETag'] = _etags[file.absolute.path] = stamp
              .millisecondsSinceEpoch
              .toString();
        }

        setCachedHeaders(stat.modified, req, res);
        return super.serveFile(file, stat, req, res);
      });
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

    //if (maxAge != null) {
    var expiry = DateTime.now().add(Duration(seconds: maxAge));
    res.headers['expires'] = HttpDate.format(expiry);
    //}
  }
}

enum CacheAccessLevel {
  public('public'),
  private('private');

  const CacheAccessLevel(this.level);
  final String level;
}
