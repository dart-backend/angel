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

  CacheService(
      {required this.database,
      required this.cache,
      this.timeout = const Duration(minutes: 10),
      this.ignoreParams = false});

  Future<T> _getCached<T>(
      Map<String, dynamic> params,
      _CachedItem? Function() get,
      FutureOr<T> Function() getFresh,
      FutureOr<T> Function() getCached,
      FutureOr<T> Function(T data, DateTime now) save) async {
    var cached = get();
    var now = DateTime.now().toUtc();

    if (cached != null) {
      // If the entry has expired, don't send from the cache
      var expired = now.difference(cached.timestamp) >= timeout;

      if (!expired) {
        // Read from the cache if necessary
        var queryEqual = ignoreParams == true ||
            (cached.params != null &&
                const MapEquality().equals(
                    params['query'] as Map, cached.params['query'] as Map));
        if (queryEqual) {
          return await getCached();
        }
      }
    }

    // If we haven't fetched from the cache by this point,
    // let's fetch from the database.
    var data = await getFresh();
    await save(data, now);
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
        _indexed = _CachedItem(params, now, data);
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
        _cache[id] = _CachedItem(params, now, data);
        return await cache.modify(id, data);
      },
    );
  }

  @override
  Future<Data> create(data, [Map<String, dynamic>? params]) {
    _indexed = null;
    return database.create(data, params);
  }

  @override
  Future<Data> modify(Id id, Data data, [Map<String, dynamic>? params]) {
    _indexed = null;
    _cache.remove(id);
    return database.modify(id, data, params);
  }

  @override
  Future<Data> update(Id id, Data data, [Map<String, dynamic>? params]) {
    _indexed = null;
    _cache.remove(id);
    return database.modify(id, data, params);
  }

  @override
  Future<Data> remove(Id id, [Map<String, dynamic>? params]) {
    _indexed = null;
    _cache.remove(id);
    return database.remove(id, params);
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
