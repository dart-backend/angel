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
  /// It must store records as given: a [MapService] needs
  /// `autoIdAndDateFields: false`, or the cached copies get their own ids and
  /// dates.
  final Service<Id, Data> cache;

  /// If `true` (default: `false`), then result caching will discard parameters passed to service methods.
  ///
  /// If you want to return a cached result more-often-than-not, you may want to enable this.
  final bool ignoreParams;

  final Duration timeout;

  final Map<Id, _CachedItem<Data>> _cache = {};
  _CachedItem<List<Data>>? _indexed;

  /// Orders reads and writes, so that a read (or index) that overlapped a
  /// write does not store what the database returned before it.
  int _clock = 0;

  /// The writes of each id still in progress, and of all ids.
  final Map<Id, int> _pending = {};
  int _pendingTotal = 0;

  /// When each id was last written, by [_clock] and time; kept as long as
  /// cached entries, so it does not grow with every id ever written.
  final Map<Id, (int, DateTime)> _lastWrite = {};

  /// When any record was last written, by [_clock].
  int _lastAnyWrite = 0;

  /// When ended entries were last removed from [_cache].
  DateTime? _lastPrune;

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
    var start = _clock;
    return _getCached(
      params ?? {},
      () => _indexed,
      () => database.index(params),
      // A copy, so a caller changing the list does not change the cache's.
      // Its items are shared.
      () => List.of(_indexed?.data ?? <Data>[]),
      (data, now) async {
        // A write since the list was read changed it.
        if (_pendingTotal > 0 || _lastAnyWrite > start) return data;
        // Its own copy, as the caller may change the list it gets.
        _indexed = _CachedItem(params ?? const {}, now, List.of(data));
        return data;
      },
    );
  }

  @override
  Future<Data> read(Id id, [Map<String, dynamic>? params]) async {
    var start = _clock;
    bool writtenSince() =>
        (_pending[id] ?? 0) > 0 || (_lastWrite[id]?.$1 ?? 0) > start;

    return _getCached<Data>(
      params ?? {},
      () => _cache[id],
      () => database.read(id, params),
      () => cache.read(id),
      (data, now) async {
        // Written since it was read: the write stores the newer version.
        if (writtenSince()) return data;
        _prune(now);
        _cache[id] = _CachedItem(params ?? const {}, now, data);
        // update() stores the item under [id] even if the cache lacks it;
        // modify() (PATCH) does not create missing items.
        var stored = await cache.update(id, data);
        // A write that ended meanwhile may have been overwritten.
        if ((_lastWrite[id]?.$1 ?? 0) > start) {
          _cache.remove(id);
          await _evict(id);
        }
        return stored;
      },
    );
  }

  @override
  Future<Data> create(data, [Map<String, dynamic>? params]) =>
      _write(null, () => database.create(data, params));

  /// Removes the ended entries of [_cache], at most once per [timeout], so
  /// it does not keep every record ever read.
  void _prune(DateTime now) {
    var last = _lastPrune;
    var since = last == null ? null : now.difference(last);
    if (since != null && !since.isNegative && since < timeout) return;
    _lastPrune = now;
    _cache.removeWhere((_, item) => now.difference(item.timestamp) >= timeout);
    _lastWrite.removeWhere((_, write) => now.difference(write.$2) >= timeout);
  }

  /// Runs the write [f] of [id] (of a new record, if `null`), recording it
  /// for the reads it overlaps.
  Future<Data> _write(Id? id, Future<Data> Function() f) async {
    _indexed = null;
    if (id != null) {
      _cache.remove(id);
      _pending[id] = (_pending[id] ?? 0) + 1;
    }
    _pendingTotal++;
    try {
      return await f();
    } finally {
      var seq = ++_clock;
      _lastAnyWrite = seq;
      _pendingTotal--;
      _indexed = null;
      if (id != null) {
        var now = DateTime.now().toUtc();
        _lastWrite[id] = (seq, now);
        _prune(now);
        var left = _pending[id]! - 1;
        if (left == 0) {
          _pending.remove(id);
        } else {
          _pending[id] = left;
        }
      }
    }
  }

  @override
  Future<Data> modify(Id id, Data data, [Map<String, dynamic>? params]) =>
      _write(id, () async {
        var result = await database.modify(id, data, params);
        await _writeThrough(id, result);
        return result;
      });

  @override
  Future<Data> update(Id id, Data data, [Map<String, dynamic>? params]) =>
      _write(id, () async {
        var result = await database.update(id, data, params);
        await _writeThrough(id, result);
        return result;
      });

  @override
  Future<Data> remove(Id id, [Map<String, dynamic>? params]) =>
      _write(id, () async {
        var result = await database.remove(id, params);
        await _evict(id);
        return result;
      });

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
