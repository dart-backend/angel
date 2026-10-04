import 'package:angel3_container/angel3_container.dart';

final RegExp straySlashes = RegExp(r'(^/+)|(/+$)');

T? matchingAnnotation<T>(List<ReflectedInstance> metadata) {
  for (var metaDatum in metadata) {
    if (metaDatum.type.reflectedType == T) {
      return metaDatum.reflectee as T?;
    }
  }

  return null;
}

/// Returns `true` if [reflector] can perform reflection.
///
/// [ThrowingReflector] (the default for `Angel()`) means reflection is
/// disabled, e.g. in AOT-compiled apps where `dart:mirrors` is unavailable.
bool canReflect(Reflector? reflector) =>
    reflector != null && reflector is! ThrowingReflector;

/// Reads the [T] annotation on [obj], or returns `null` when reflection is
/// disabled (see [canReflect]), so annotations are simply ignored.
T? getAnnotation<T>(Object obj, Reflector? reflector) {
  if (reflector == null || !canReflect(reflector)) {
    return null;
  } else {
    if (obj is Function) {
      var methodMirror = reflector.reflectFunction(obj)!;
      return matchingAnnotation<T>(methodMirror.annotations);
    } else {
      var classMirror = reflector.reflectClass(obj.runtimeType)!;
      return matchingAnnotation<T>(classMirror.annotations);
    }
  }
}
