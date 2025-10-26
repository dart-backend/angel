import 'dart:async';
import 'package:angel3_framework/angel3_framework.dart';

/// A middleware that enables the caching of response serialization.
///
/// This can improve the performance of sending objects that are complex to serialize.
///
/// You can pass a [shouldCache] callback to determine which values should be cached.
RequestHandler cacheSerializationResults({
  Duration? timeout,
  FutureOr<bool> Function(RequestContext, ResponseContext, Object)? shouldCache,
}) {
  return (RequestContext req, ResponseContext res) async {
    var oldSerializer = res.serializer;

    // TODO: Commented out as it is not doing anything useful
    var cache = <dynamic, String>{};

    res.serializer = (value) {
      if (shouldCache == null) {
        return cache.putIfAbsent(value, () => oldSerializer(value) as String);
      }

      return oldSerializer(value);
    };

    return true;
  };
}
