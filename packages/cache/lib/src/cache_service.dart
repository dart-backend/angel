import 'dart:async';

import 'package:collection/collection.dart';
import 'package:angel3_framework/angel3_framework.dart';

/// An Angel [Service] that caches data from another service.
///
/// This is useful for applications of scale, where network latency
/// can have real implications on application performance.
class CacheService<Id, Data> extends Service<Id, Data> {
  /// The underlying [Service] that represents the original data store.
  final Service<Id, Data> database;

  /// The [Service] used to interface with a caching layer.
  ///
  /// If not provided, this defaults to a [MapService].
  final Service<Id, Data> cache;

  /// If `true` (default: `false`), then result caching will discard parameters passed to service methods.
  ///
  /// If you want to return a cached result more-often-than-not, you may want to enable this.
  final bool ignoreParams;

  final Duration timeout;

  final Map<Id, _CachedItem<Data>> _cache = {};
  _CachedItem<List<Data>>? _indexed;

  CacheService({
    required this.database,
    required this.cache,
    this.timeout = const Duration(minutes: 10),
    this.ignoreParams = false,
  });

  Future<T> _getCached<T>(
    Map<String, dynamic> params,
    _CachedItem? Function() get,
    FutureOr<T> Function() getFresh,
    FutureOr<T> Function() getCached,
    FutureOr<T> Function(T data, DateTime now) save,
  ) async {
    var cached = get();
    var now = DateTime.now().toUtc();

    if (cached != null) {
      // If the entry has expired, don't send from the cache
      var expired = now.difference(cached.timestamp) >= timeout;

      if (!expired) {
        // Read from the cache if the query matches. A missing query (e.g.
        // a server-side call without params) matches another missing one.
        var queryEqual =
            ignoreParams == true ||
            const DeepCollectionEquality().equals(
              params['query'],
              (cached.params as Map?)?['query'],
            );
        if (queryEqual) {
          try {
            return await getCached();
          } catch (_) {
            // The cache no longer has the item (e.g. another instance
            // evicted it after a write) or is unavailable: use the database.
          }
        }
      }
    }

    // If we haven't fetched from the cache by this point,
    // let's fetch from the database.
    var data = await getFresh();
    try {
      await save(data, now);
    } catch (_) {
      // A failing cache must not fail the read; the data is still valid.
    }
    return data;
  }

  @override
  Future<List<Data>> index([Map<String, dynamic>? params]) {
    return _getCached(
      params ?? {},
      () => _indexed,
      () => database.index(params),
      () => _indexed?.data ?? [],
      (data, now) async {
        _indexed = _CachedItem(params ?? const {}, now, data);
        return data;
      },
    );
  }

  @override
  Future<Data> read(Id id, [Map<String, dynamic>? params]) async {
    return _getCached<Data>(
      params ?? {},
      () => _cache[id],
      () => database.read(id, params),
      () => cache.read(id),
      (data, now) async {
        _cache[id] = _CachedItem(params ?? const {}, now, data);
        // update() stores the item under [id] even if the cache lacks it;
        // modify() (PATCH) does not create missing items.
        return await cache.update(id, data);
      },
    );
  }

  @override
  Future<Data> create(data, [Map<String, dynamic>? params]) {
    _indexed = null;
    return database.create(data, params);
  }

  @override
  Future<Data> modify(Id id, Data data, [Map<String, dynamic>? params]) async {
    _indexed = null;
    _cache.remove(id);
    var result = await database.modify(id, data, params);
    await _writeThrough(id, result);
    return result;
  }

  @override
  Future<Data> update(Id id, Data data, [Map<String, dynamic>? params]) async {
    _indexed = null;
    _cache.remove(id);
    var result = await database.update(id, data, params);
    await _writeThrough(id, result);
    return result;
  }

  @override
  Future<Data> remove(Id id, [Map<String, dynamic>? params]) async {
    _indexed = null;
    _cache.remove(id);
    var result = await database.remove(id, params);
    await _evict(id);
    return result;
  }

  /// Stores the database's new version of [id] in the shared [cache], so
  /// that other instances using the same cache do not serve the old one.
  Future<void> _writeThrough(Id id, Data data) async {
    try {
      await cache.update(id, data);
    } catch (_) {
      // If the cache cannot store it, at least do not leave the old version.
      await _evict(id);
    }
  }

  /// Removes [id] from the shared [cache], ignoring a missing entry or an
  /// unavailable cache (reads fall back to the database).
  Future<void> _evict(Id id) async {
    try {
      await cache.remove(id);
    } catch (_) {
      // Nothing cached, or the cache is unavailable.
    }
  }
}

class _CachedItem<Data> {
  final dynamic params;
  final DateTime timestamp;
  final Data? data;

  _CachedItem(this.params, this.timestamp, [this.data]);

  @override
  String toString() {
    return '$timestamp:$params:$data';
  }
}
