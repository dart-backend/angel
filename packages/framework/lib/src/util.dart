import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_route/angel3_route.dart';
import 'package:logging/logging.dart';

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
///
/// Also `null` when [reflector] has no information about [obj], as a
/// [StaticReflector] or a generated reflector may not for every handler.
T? getAnnotation<T>(Object obj, Reflector? reflector) {
  if (reflector == null || !canReflect(reflector)) {
    return null;
  }
  var annotations = tryReflect(
    () => obj is Function
        ? reflector.reflectFunction(obj)?.annotations
        : reflector.reflectClass(obj.runtimeType)?.annotations,
  );
  return annotations == null ? null : matchingAnnotation<T>(annotations);
}

/// Reads the [T] annotation on the method [name] of [obj], whose tear-off is
/// [method]: from the tear-off (with `dart:mirrors`), or else from the
/// declaration of [name] in the class of [obj] (e.g. with generated reflection
/// data, which cannot describe tear-offs).
T? getMethodAnnotation<T>(
  Object obj,
  String name,
  Function method,
  Reflector? reflector,
) {
  if (reflector == null || !canReflect(reflector)) return null;
  var function = tryReflect(() => reflector.reflectFunction(method));
  if (function != null) return matchingAnnotation<T>(function.annotations);
  var declarations = tryReflect(() => reflector.reflectClass(obj.runtimeType))
      ?.declarations;
  for (var declaration in declarations ?? const <ReflectedDeclaration>[]) {
    var function = declaration.function;
    if (declaration.name == name && function != null) {
      return matchingAnnotation<T>(function.annotations);
    }
  }
  return null;
}

/// The classes [warnIfUndescribed] has warned about, by reflector.
final Expando<Set<Type>> _warnedUndescribed = Expando('undescribed');

/// Logs a warning to [logger], once per [reflector] and [type], when
/// [reflector] reflects (see [canReflect]) but has no information about
/// [type], as a [StaticReflector] has none about a class that is not
/// `@injectable`: then the [annotations] of [type] and of its methods (e.g.
/// `@Middleware`, which may guard it) are ignored without it.
///
/// Not for [skip], classes known to carry none, nor for an [EmptyReflector],
/// which describes nothing by design.
void warnIfUndescribed(
  Reflector reflector,
  Type type,
  Logger logger,
  String annotations, {
  Set<Type> skip = const {},
}) {
  if (!canReflect(reflector) ||
      reflector is EmptyReflector ||
      skip.contains(type)) {
    return;
  }
  if (tryReflect(() => reflector.reflectClass(type)) != null) return;
  var warned = _warnedUndescribed[reflector] ??= {};
  if (!warned.add(type)) return;
  logger.warning(
    'The reflector has no information about $type, so its $annotations, and '
    'those of its methods, are ignored. With a StaticReflector, mark $type '
    '@injectable and pass its reflection data to StaticReflector.combine.',
  );
}

/// Runs [reflect], or returns `null` when the reflector has no information
/// about what it reflects upon, as a [StaticReflector] or a generated
/// reflector may not for every type and function.
T? tryReflect<T>(T? Function() reflect) {
  try {
    return reflect();
  } on ArgumentError {
    return null;
  } on UnsupportedError {
    return null;
  }
}

/// Resolves [path] for a request with the given HTTP [method].
///
/// A `HEAD` request with no explicit `HEAD` route is resolved as `GET`
/// when a `GET` route matches, so every `GET` route also answers `HEAD`
/// (RFC 9110). Routes for any method (such as fallbacks) match both, which
/// is why the answering route's method is checked rather than emptiness.
List<RoutingResult<T>> resolveRequest<T>(
  Router<T> router,
  String path,
  String method, {
  bool strip = true,
}) {
  List<RoutingResult<T>> resolve(String m) =>
      router.resolveAbsolute(path, method: m, strip: strip).toList();
  bool answeredBy(List<RoutingResult<T>> results, String m) =>
      results.any((r) => r.deepest.shallowRoute.method == m);

  var resolved = resolve(method);
  if (method != 'HEAD' || answeredBy(resolved, 'HEAD')) return resolved;

  var asGet = resolve('GET');
  return answeredBy(asGet, 'GET') ? asGet : resolved;
}
