import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';

/// A middleware that enables the caching of response serialization.
///
/// This can improve the performance of sending objects that are complex to
/// serialize and are returned again and again, such as a precomputed list or
/// a shared configuration object.
///
/// Results are cached per object *instance* (not by value), across all
/// requests that pass through this middleware, and are held weakly, so a
/// cached object can still be garbage-collected. Strings, numbers, booleans,
/// records and `null` are never cached; they are cheap to serialize.
///
/// A cached result is reused only for the same underlying serializer. Since
/// the cache cannot see changes inside an object, use [timeout] (or avoid
/// this middleware) for objects that are mutated after being served.
///
/// [shouldCache], if given, decides per value whether its result may be
/// cached. [timeout], if given, is how long a cached result stays valid.
RequestHandler cacheSerializationResults({
  Duration? timeout,
  FutureOr<bool> Function(RequestContext, ResponseContext, Object)? shouldCache,
}) {
  final cache = Expando<_SerializedResult>('cacheSerializationResults');

  return (RequestContext req, ResponseContext res) {
    var inner = res.serializer;

    res.serializer = (value) {
      if (!_canCache(value)) return inner(value);
      var key = value as Object;
      var now = DateTime.now();

      var cached = cache[key];
      if (cached != null &&
          identical(cached.serializer, inner) &&
          (timeout == null || now.difference(cached.time) < timeout)) {
        return cached.text;
      }

      String save(String text) {
        cache[key] = _SerializedResult(text, inner, now);
        return text;
      }

      // Stay synchronous when the serializer is, since some callers (such
      // as `res.jsonp`) do not await the result.
      FutureOr<String> serializeAndSave() {
        var text = inner(value);
        return text is Future<String> ? text.then(save) : save(text);
      }

      if (shouldCache == null) return serializeAndSave();

      var decision = shouldCache(req, res, key);
      if (decision is Future<bool>) {
        return decision.then((ok) => ok ? serializeAndSave() : inner(value));
      }
      return decision ? serializeAndSave() : inner(value);
    };

    return true;
  };
}

/// Whether [value] can be a cache key. [Expando] does not accept these, and
/// they are cheap to serialize anyway.
bool _canCache(Object? value) =>
    value != null &&
    value is! String &&
    value is! num &&
    value is! bool &&
    value is! Record;

class _SerializedResult {
  final String text;
  final FutureOr<String> Function(dynamic) serializer;
  final DateTime time;

  _SerializedResult(this.text, this.serializer, this.time);
}
