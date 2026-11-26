import 'dart:collection';

/// A [Map] of at most [maxSize] entries, which evicts the least recently
/// used entry to make room for a new one.
///
/// Reading an entry with `[]`, or setting it, makes it the most recently
/// used; [keys], [values] and [entries] list the least recently used first,
/// without changing the order. Every operation takes constant time, whereas
/// evicting the first key of a [LinkedHashMap] that entries are removed from
/// and added to again takes time that grows with the entries removed.
class LruMap<K, V> extends MapBase<K, V> {
  final HashMap<K, _LruEntry<K, V>> _entries = HashMap();

  /// The least recently used entry, and the most recently used.
  _LruEntry<K, V>? _oldest, _newest;

  int _maxSize;

  /// A map of at most [maxSize] entries; one of 0 or less holds none.
  LruMap(int maxSize) : _maxSize = maxSize;

  /// The most entries this map holds.
  ///
  /// Setting a smaller size evicts the least recently used entries at once.
  int get maxSize => _maxSize;

  set maxSize(int value) {
    _maxSize = value;
    _evict();
  }

  @override
  int get length => _entries.length;

  @override
  bool containsKey(Object? key) => _entries.containsKey(key);

  @override
  V? operator [](Object? key) {
    var entry = _entries[key];
    if (entry == null) return null;
    _touch(entry);
    return entry.value;
  }

  @override
  void operator []=(K key, V value) {
    var entry = _entries[key];
    if (entry != null) {
      entry.value = value;
      _touch(entry);
      return;
    }
    if (_maxSize <= 0) return;
    entry = _LruEntry(key, value);
    _entries[key] = entry;
    _append(entry);
    _evict();
  }

  @override
  V? remove(Object? key) {
    var entry = _entries.remove(key);
    if (entry == null) return null;
    _unlink(entry);
    return entry.value;
  }

  @override
  void clear() {
    _entries.clear();
    _oldest = _newest = null;
  }

  @override
  Iterable<K> get keys sync* {
    for (var e = _oldest; e != null; e = e.next) {
      yield e.key;
    }
  }

  void _evict() {
    while (_entries.length > (_maxSize < 0 ? 0 : _maxSize)) {
      var oldest = _oldest!;
      _entries.remove(oldest.key);
      _unlink(oldest);
    }
  }

  void _touch(_LruEntry<K, V> entry) {
    if (identical(entry, _newest)) return;
    _unlink(entry);
    _append(entry);
  }

  void _append(_LruEntry<K, V> entry) {
    entry
      ..previous = _newest
      ..next = null;
    _newest?.next = entry;
    _newest = entry;
    _oldest ??= entry;
  }

  void _unlink(_LruEntry<K, V> entry) {
    var previous = entry.previous, next = entry.next;
    if (previous == null) {
      _oldest = next;
    } else {
      previous.next = next;
    }
    if (next == null) {
      _newest = previous;
    } else {
      next.previous = previous;
    }
    entry.previous = entry.next = null;
  }
}

class _LruEntry<K, V> {
  final K key;
  V value;
  _LruEntry<K, V>? previous, next;

  _LruEntry(this.key, this.value);
}
