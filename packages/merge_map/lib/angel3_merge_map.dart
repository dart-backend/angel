/// Exposes the [mergeMap] function, which... merges Maps.
library angel3_merge_map;

dynamic _copyValues<K, V>(
    Map<K, V> from, Map<K, V?>? to, bool recursive, bool acceptNull) {
  for (var key in from.keys) {
    if (from[key] is Map<K, V> && recursive) {
      if (!(to![key] is Map<K, V>)) {
        to[key] = <K, V>{} as V;
      }
      _copyValues(from[key] as Map, to[key] as Map?, recursive, acceptNull);
    } else {
      if (from[key] != null || acceptNull) to![key] = from[key];
    }
  }
}

/// Merges the values of the given maps together.
///
/// `recursive` is set to `true` by default. If set to `true`,
/// then nested maps will also be merged. Otherwise, nested maps
/// will overwrite others.
///
/// `acceptNull` is set to `false` by default. If set to `false`,
/// then if the value on a map is `null`, it will be ignored, and
/// that `null` will not be copied.
Map<K, V> mergeMap<K, V>(Iterable<Map<K, V>> maps,
    {bool recursive = true, bool acceptNull = false}) {
  var result = <K, V>{};
  maps.forEach((Map<K, V> map) {
    _copyValues(map, result, recursive, acceptNull);
  });
  return result;
}
