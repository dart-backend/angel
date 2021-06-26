import 'dart:async';
import 'dart:io' show HttpDate;
import 'package:angel3_framework/angel3_framework.dart';
import 'package:pool/pool.dart';
import 'package:logging/logging.dart';

/// A flexible response cache for Angel.
///
/// Use this to improve real and perceived response of Web applications,
/// as well as to memoize expensive responses.
class ResponseCache {
  /// A set of [Patterns] for which responses will be cached.
  ///
  /// For example, you can pass a `Glob` matching `**/*.png` files to catch all PNG images.
  final List<Pattern> patterns = [];

  /// An optional timeout, after which a given response will be removed from the cache, and the contents refreshed.
  final Duration timeout;

  final Map<String, _CachedResponse> _cache = {};
  final Map<String, Pool> _writeLocks = {};

  /// If `true` (default: `false`), then caching of results will discard URI query parameters and fragments.
  final bool ignoreQueryAndFragment;

  final log = Logger('ResponseCache');

  ResponseCache(
      {this.timeout = const Duration(minutes: 10),
      this.ignoreQueryAndFragment = false});

  /// Closes all internal write-locks, and closes the cache.
  Future close() async {
    _writeLocks.forEach((_, p) => p.close());
  }

  /// Removes an entry from the response cache.
  void purge(String path) => _cache.remove(path);

  /// A middleware that handles requests with an `If-Modified-Since` header.
  ///
  /// This prevents the server from even having to access the cache, and plays very well with static assets.
  Future<bool> ifModifiedSince(RequestContext req, ResponseContext res) async {
    if (req.method != 'GET' && req.method != 'HEAD') {
      return true;
    }

    var modifiedSince = req.headers?.ifModifiedSince;
    if (modifiedSince != null) {
      // Check if there is a cache entry.
      for (var pattern in patterns) {
        var reqPath = _getEffectivePath(req);

        if (pattern.allMatches(reqPath).isNotEmpty &&
            _cache.containsKey(reqPath)) {
          var response = _cache[reqPath];

          //log.info('timestamp ${response?.timestamp} vs since $modifiedSince');

          if (response != null &&
              response.timestamp.compareTo(modifiedSince) <= 0) {
            // If the cache timeout has been met, don't send the cached response.
            var timeDiff =
                DateTime.now().toUtc().difference(response.timestamp);

            //log.info(
            //    'Time Diff: ${timeDiff.inMilliseconds} >=  ${timeout.inMilliseconds}');
            if (timeDiff.inMilliseconds >= timeout.inMilliseconds) {
              return true;
            }

            // Old code: res.statusCode = 304;
            // Return the response stored in the cache
            _setCachedHeaders(response.timestamp, req, res);
            res
              ..headers.addAll(response.headers)
              ..add(response.body);
            await res.close();
            return false;
          }
        }
      }
    }

    return true;
  }

  String _getEffectivePath(RequestContext req) {
    if (req.uri == null) {
      log.severe('Request URI is null');
      throw ArgumentError('Request URI is null');
    }
    return ignoreQueryAndFragment == true ? req.uri!.path : req.uri.toString();
  }

  /// Serves content from the cache, if applicable.
  Future<bool> handleRequest(RequestContext req, ResponseContext res) async {
    if (!await ifModifiedSince(req, res)) return false;
    if (req.method != 'GET' && req.method != 'HEAD') return true;
    if (!res.isOpen) return true;

    // Check if there is a cache entry.
    //
    // If `if-modified-since` is present, this check has already been performed.
    if (req.headers?.ifModifiedSince == null) {
      for (var pattern in patterns) {
        if (pattern.allMatches(_getEffectivePath(req)).isNotEmpty) {
          var now = DateTime.now().toUtc();

          if (_cache.containsKey(_getEffectivePath(req))) {
            var response = _cache[_getEffectivePath(req)];

            if (response == null ||
                now.difference(response.timestamp) >= timeout) {
              return true;
            }

            _setCachedHeaders(response.timestamp, req, res);
            res
              ..headers.addAll(response.headers)
              ..add(response.body);
            await res.close();
            return false;
          } else {
            _setCachedHeaders(now, req, res);
          }
        }
      }
    }

    return true;
  }

  /// A response finalizer that saves responses to the cache.
  Future<bool> responseFinalizer(
      RequestContext req, ResponseContext res) async {
    if (res.statusCode == 304) {
      return true;
    }

    if (req.method != 'GET' && req.method != 'HEAD') {
      return true;
    }

    // Check if there is a cache entry.
    for (var pattern in patterns) {
      var reqPath = _getEffectivePath(req);

      if (pattern.allMatches(reqPath).isNotEmpty) {
        var now = DateTime.now().toUtc();

        // Invalidate the response, if need be.
        if (_cache.containsKey(reqPath)) {
          // If there is no timeout, don't invalidate.
          //if (timeout == null) return true;

          // Otherwise, don't invalidate unless the timeout has been exceeded.
          var response = _cache[reqPath];
          if (response == null ||
              now.difference(response.timestamp) < timeout) {
            return true;
          }

          // If the cache entry should be invalidated, then invalidate it.
          purge(reqPath);
        }

        // Save the response.
        var writeLock = _writeLocks.putIfAbsent(reqPath, () => Pool(1));
        await writeLock.withResource(() {
          if (res.buffer != null) {
            _cache[reqPath] = _CachedResponse(
                Map.from(res.headers), res.buffer!.toBytes(), now);
          }
        });

        _setCachedHeaders(now, req, res);
      }
    }

    return true;
  }

  void _setCachedHeaders(
      DateTime modified, RequestContext req, ResponseContext res) {
    var privacy = 'public';

    res.headers
      ..['cache-control'] = '$privacy, max-age=${timeout.inSeconds}'
      ..['last-modified'] = HttpDate.format(modified);

    var expiry = DateTime.now().add(timeout);
    res.headers['expires'] = HttpDate.format(expiry);
  }
}

class _CachedResponse {
  final Map<String, String> headers;
  final List<int> body;
  final DateTime timestamp;

  _CachedResponse(this.headers, this.body, this.timestamp);
}
