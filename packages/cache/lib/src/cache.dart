import 'dart:async';
import 'dart:io' show HttpDate;

import 'package:angel3_framework/angel3_framework.dart';
import 'package:logging/logging.dart';

/// A flexible response cache for Angel.
///
/// Use this to improve real and perceived response of Web applications,
/// as well as to memorize expensive responses.
///
/// Only responses that are safe to share are stored: status 200, no
/// `Set-Cookie`, no `Cache-Control: no-store` or `private`, and not for a
/// request carrying `Authorization` (such requests also bypass the cache).
class ResponseCache {
  /// A set of [Patterns] for which responses will be cached.
  ///
  /// For example, you can pass a `Glob` matching `**/*.png` files to catch all PNG images.
  final List<Pattern> patterns = [];

  /// An optional timeout, after which a given response will be removed from the cache, and the contents refreshed.
  final Duration timeout;

  /// The maximum number of cached responses; `0` disables storing.
  ///
  /// When full, expired entries are dropped first, then the least recently
  /// used. Without a bound, requests for distinct URLs (e.g. varying query
  /// strings) would grow the cache indefinitely.
  final int maxEntries;

  /// Cached responses by effective path, least recently used first.
  final Map<String, _CachedResponse> _cache = {};

  /// If `true` (default: `false`), then caching of results will discard URI query parameters and fragments.
  final bool ignoreQueryAndFragment;

  final log = Logger('ResponseCache');

  ResponseCache({
    this.timeout = const Duration(minutes: 10),
    this.ignoreQueryAndFragment = false,
    this.maxEntries = 1024,
  });

  /// Closes the cache, discarding all entries.
  Future close() async {
    _cache.clear();
  }

  /// Removes an entry from the response cache.
  void purge(String path) => _cache.remove(path);

  /// A middleware that handles requests with an `If-Modified-Since` header.
  ///
  /// This prevents the server from even having to access the cache, and plays very well with static assets.
  Future<bool> ifModifiedSince(RequestContext req, ResponseContext res) async {
    if (!_isCacheableRequest(req)) return true;

    var modifiedSince = req.headers?.ifModifiedSince;
    if (modifiedSince == null) return true;

    var reqPath = _getEffectivePath(req);
    if (!_matches(reqPath)) return true;

    var response = _lookup(reqPath, DateTime.now().toUtc());
    if (response != null && response.timestamp.compareTo(modifiedSince) <= 0) {
      await _send(response, req, res);
      return false;
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

  bool _matches(String path) =>
      patterns.any((pattern) => pattern.allMatches(path).isNotEmpty);

  /// Only `GET`/`HEAD` requests without credentials use the cache: a
  /// response to an authenticated request may be specific to that user.
  static bool _isCacheableRequest(RequestContext req) =>
      (req.method == 'GET' || req.method == 'HEAD') &&
      (req.headers?['authorization'] ?? const []).isEmpty;

  /// Whether [res] may be stored and replayed to other clients.
  static bool _isCacheableResponse(ResponseContext res) {
    if (res.statusCode != 200) return false;
    if (res.cookies.isNotEmpty || res.headers.containsKey('set-cookie')) {
      return false;
    }
    var directives = (res.headers['cache-control'] ?? '')
        .toLowerCase()
        .split(',')
        .map((d) => d.trim().split('=').first);
    return !directives.contains('no-store') && !directives.contains('private');
  }

  /// Returns the fresh entry for [path], dropping it if it has expired.
  _CachedResponse? _lookup(String path, DateTime now) {
    var response = _cache.remove(path);
    if (response == null) return null;
    if (now.difference(response.timestamp) >= timeout) return null;
    // Re-inserting marks it most recently used.
    return _cache[path] = response;
  }

  void _store(String path, _CachedResponse response, DateTime now) {
    _cache.remove(path);
    if (maxEntries <= 0) return;

    if (_cache.length >= maxEntries) {
      _cache.removeWhere((_, r) => now.difference(r.timestamp) >= timeout);
    }
    while (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[path] = response;
  }

  Future<void> _send(
    _CachedResponse response,
    RequestContext req,
    ResponseContext res,
  ) async {
    _setCachedHeaders(response.timestamp, req, res);
    res
      ..statusCode = response.statusCode
      ..headers.addAll(response.headers)
      ..add(response.body);
    await res.close();
  }

  /// Serves content from the cache, if applicable.
  Future<bool> handleRequest(RequestContext req, ResponseContext res) async {
    if (!await ifModifiedSince(req, res)) return false;
    if (!_isCacheableRequest(req)) return true;
    if (!res.isOpen) return true;

    // If `if-modified-since` is present, this check has already been performed.
    if (req.headers?.ifModifiedSince != null) return true;

    var reqPath = _getEffectivePath(req);
    if (!_matches(reqPath)) return true;

    var response = _lookup(reqPath, DateTime.now().toUtc());
    if (response == null) return true;

    await _send(response, req, res);
    return false;
  }

  /// A response finalizer that saves responses to the cache.
  ///
  /// Only buffered responses (see `ResponseContext.useBuffer`) can be stored.
  /// Cache headers are added only to responses that are safe to cache.
  Future<bool> responseFinalizer(
    RequestContext req,
    ResponseContext res,
  ) async {
    if (!_isCacheableRequest(req) || !_isCacheableResponse(res)) return true;

    var reqPath = _getEffectivePath(req);
    if (!_matches(reqPath)) return true;

    var now = DateTime.now().toUtc();

    // Keep a fresh entry; replace an expired one.
    if (_lookup(reqPath, now) != null) return true;

    if (res.buffer != null) {
      _store(
        reqPath,
        _CachedResponse(
          res.statusCode,
          Map.from(res.headers),
          res.buffer!.toBytes(),
          now,
        ),
        now,
      );
    }

    _setCachedHeaders(now, req, res);
    return true;
  }

  void _setCachedHeaders(
    DateTime modified,
    RequestContext req,
    ResponseContext res,
  ) {
    var privacy = 'public';

    res.headers
      ..['cache-control'] = '$privacy, max-age=${timeout.inSeconds}'
      ..['last-modified'] = HttpDate.format(modified);

    var expiry = DateTime.now().add(timeout);
    res.headers['expires'] = HttpDate.format(expiry);
  }
}

class _CachedResponse {
  final int statusCode;
  final Map<String, String> headers;
  final List<int> body;
  final DateTime timestamp;

  _CachedResponse(this.statusCode, this.headers, this.body, this.timestamp);
}
