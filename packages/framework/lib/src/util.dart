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

T? getAnnotation<T>(obj, Reflector? reflector) {
  if (reflector == null) {
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
