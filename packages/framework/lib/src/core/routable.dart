library;

import 'dart:async';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_route/angel3_route.dart';

import '../util.dart';
import 'hooked_service.dart';
import 'metadata.dart';
import 'request_context.dart';
import 'response_context.dart';
import 'service.dart';

final RegExp _straySlashes = RegExp(r'(^/+)|(/+$)');

/// A function that receives an incoming [RequestContext] and responds to it.
typedef RequestHandler = FutureOr<dynamic> Function(
  RequestContext<dynamic> req,
  ResponseContext<dynamic> res,
);

/// Sequentially runs a list of [handlers] of middleware, and returns early if any does not
/// return `true`. Works well with [Router].chain.
RequestHandler chain(Iterable<RequestHandler> handlers) {
  return (req, res) async {
    // Like a route's own handlers: each must return `true` for the next to
    // run, and results other than `bool` are serialized.
    for (var handler in handlers) {
      if (!res.isOpen) return false;
      if (await req.app!.executeHandler(handler, req, res) != true) {
        return false;
      }
    }
    return true;
  };
}

/// A routable server that can handle dynamic requests.
class Routable extends Router<RequestHandler> {
  final Map<Pattern, Service> _services = {};
  final Map<Pattern, Service?> _serviceLookups = {};

  /// A [Map] of application-specific data that can be accessed.
  ///
  /// Packages like `package:angel3_configuration` populate this map
  /// for you.
  final Map configuration = {};

  final Container _container;

  Routable([Reflector? reflector])
    //      : _container = reflector == null ? null : Container(reflector),
    : _container = Container(reflector ?? const ThrowingReflector()),
      super();

  /// A [Container] used to inject dependencies.
  Container get container => _container;

  void close() {
    _services.clear();
    configuration.clear();
    _onService.close();
  }

  /// A set of [Service] objects that have been mapped into routes.
  Map<Pattern, Service> get services => _services;

  final StreamController<Service> _onService =
      StreamController<Service>.broadcast();

  /// Fired whenever a service is added to this instance.
  ///
  /// **NOTE**: This is a broadcast stream.
  Stream<Service> get onService => _onService.stream;

  /// Retrieves the service assigned to the given path.
  T? findService<T extends Service>(Pattern path) {
    var found =
        _serviceLookups[path] ??
        _services[path] ??
        _services[path.toString().replaceAll(_straySlashes, '')];
    // Misses are not cached, so a service mounted later is still found.
    if (found != null) _serviceLookups[path] = found;
    return found as T?;
  }

  /// Shorthand for finding a [Service] in a statically-typed manner.
  Service<Id, Data>? findServiceOf<Id, Data>(Pattern path) {
    return findService<Service<Id, Data>>(path);
  }

  /// Shorthand for finding a [HookedService] in a statically-typed manner.
  HookedService<dynamic, dynamic, T>? findHookedService<T extends Service>(
    Pattern path,
  ) {
    return findService(path) as HookedService<dynamic, dynamic, T>?;
  }

  @override
  Route<RequestHandler> addRoute(
    String method,
    String path,
    RequestHandler handler, {
    Iterable<RequestHandler> middleware = const {},
  }) {
    final handlers = <RequestHandler>[];
    // Merge @Middleware declaration, if any
    var middlewareDeclaration = getAnnotation<Middleware>(
      handler,
      _container.reflector,
    );
    if (middlewareDeclaration != null) {
      handlers.addAll(middlewareDeclaration.handlers);
    }

    final handlerSequence = <RequestHandler>[];
    handlerSequence.addAll(middleware);
    handlerSequence.addAll(handlers);

    return super.addRoute(
      method,
      path.toString(),
      handler,
      middleware: handlerSequence,
    );
  }

  /// Mounts a [service] at the given [path].
  ///
  /// Returns a [HookedService] that can be used to hook into
  /// events dispatched by this service.
  HookedService<Id, Data, T> use<Id, Data, T extends Service<Id, Data>>(
    String path,
    T service,
  ) {
    var hooked = HookedService<Id, Data, T>(service);
    // A lookup cached for this path may name a replaced service.
    _serviceLookups.clear();
    _services[path.toString().trim().replaceAll(RegExp(r'(^/+)|(/+$)'), '')] =
        hooked;
    hooked.addRoutes();
    mount(path.toString(), hooked);
    service.onHooked(hooked);
    _onService.add(hooked);
    return hooked;
  }
}
