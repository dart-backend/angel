library;

import 'dart:async';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_route/angel3_route.dart';
import 'package:meta/meta.dart';
import 'package:recase/recase.dart';

import '../core/core.dart';
import '../util.dart';

/// Supports grouping routes with shared functionality.
class Controller {
  Angel? _app;

  /// The [Angel] application powering this controller.
  Angel get app {
    if (_app == null) {
      throw ArgumentError("Angel is not instantiated.");
    }

    return _app!;
  }

  /// If `true` (default), this class will inject itself as a singleton into the [app]'s container when bootstrapped.
  final bool injectSingleton;

  /// Middleware to run before all handlers in this class.
  List<RequestHandler> middleware = [];

  /// A mapping of route paths to routes, produced from the [Expose] annotations on this class.
  Map<String, Route> routeMappings = {};

  SymlinkRoute<RequestHandler>? _mountPoint;

  /// The route at which this controller is mounted on the server.
  SymlinkRoute<RequestHandler>? get mountPoint => _mountPoint;

  /// Mount path, name and middleware for this controller, used in place of a
  /// class-level `@Expose` annotation.
  ///
  /// Set this when reflection is disabled (e.g. AOT-compiled apps), since
  /// annotations cannot be read then. Without it, the path is derived from
  /// the class name, which is unreliable once code is obfuscated.
  final Expose? expose;

  Controller({this.injectSingleton = true, this.expose});

  /// Applies routes, DI, and other configuration to an [app].
  @mustCallSuper
  Future<void> configureServer(Angel app) async {
    _app = app;

    if (injectSingleton != false) {
      if (!app.container.has(runtimeType)) {
        _app!.container.registerSingleton(this, as: runtimeType);
      }
    }

    var name = await applyRoutes(app, app.container.reflector);
    app.controllers[name] = this;
    //return null;
  }

  /// Applies the routes from this [Controller] to some [router].
  ///
  /// When reflection is disabled (see [canReflect]), only the routes added in
  /// [configureRoutes] are applied; `@Expose` methods are not discovered.
  Future<String> applyRoutes(
    Router<RequestHandler> router,
    Reflector reflector,
  ) async {
    // Load global expose decl
    var exposeDecl = findExpose(reflector);

    if (exposeDecl == null) {
      throw Exception('All controllers must carry an @Expose() declaration.');
    }

    var routable = Routable();
    _mountPoint = router.mount(exposeDecl.path, routable);
    await configureRoutes(routable);

    String name;
    if (canReflect(reflector)) {
      // Pre-reflect methods
      var classMirror = reflector.reflectClass(runtimeType)!;
      var instanceMirror = reflector.reflectInstance(this);
      final handlers = <RequestHandler>[
        ...exposeDecl.middleware,
        ...middleware,
      ];
      classMirror.declarations.forEach(
        _routeBuilder(reflector, instanceMirror, routable, handlers),
      );
      name = reflector.reflectType(runtimeType)!.name;
    } else {
      name = runtimeType.toString();
    }

    // Return the name.
    return exposeDecl.as?.isNotEmpty == true ? exposeDecl.as! : name;
  }

  void Function(ReflectedDeclaration) _routeBuilder(
    Reflector reflector,
    ReflectedInstance? instanceMirror,
    Routable routable,
    Iterable<RequestHandler> handlers,
  ) {
    return (ReflectedDeclaration decl) {
      var methodName = decl.name;

      // Ignore built-in methods.
      if (methodName != 'toString' &&
          methodName != 'noSuchMethod' &&
          methodName != 'call' &&
          methodName != 'equals' &&
          methodName != '==') {
        var exposeDecl =
            decl.function!.annotations
                    .map((m) => m.reflectee)
                    .firstWhere((r) => r is Expose, orElse: () => null)
                as Expose?;

        if (exposeDecl == null) {
          // If this has a @noExpose, return null.
          if (decl.function!.annotations.any((m) => m.reflectee is NoExpose)) {
            return;
          } else {
            // Otherwise, create an @Expose.
            exposeDecl = Expose('');
          }
        }

        var reflectedMethod =
            instanceMirror!.getField(methodName).reflectee as Function?;
        var middleware = <RequestHandler>[
          ...handlers,
          ...exposeDecl.middleware,
        ];
        var name = exposeDecl.as?.isNotEmpty == true
            ? exposeDecl.as
            : methodName;

        // Check if normal
        var method = decl.function!;
        if (method.parameters.length == 2 &&
            method.parameters[0].type.reflectedType == RequestContext &&
            method.parameters[1].type.reflectedType == ResponseContext) {
          // Create a regular route
          routeMappings[name ?? ''] = routable.addRoute(
            exposeDecl.method,
            exposeDecl.path,
            (RequestContext req, ResponseContext res) {
              var result = reflectedMethod!(req, res);
              return result is RequestHandler ? result(req, res) : result;
            },
            middleware: middleware,
          );
          return;
        }

        var injection = preInject(reflectedMethod!, reflector);

        if (exposeDecl.allowNull.isNotEmpty == true) {
          injection.optional.addAll(exposeDecl.allowNull);
        }

        // If there is no path, reverse-engineer one.
        var path = exposeDecl.path;
        var httpMethod = exposeDecl.method;
        if (path == '') {
          // Try to build a route path by finding all potential
          // path segments, and then joining them.
          var parts = <String>[];

          // If the name starts with get/post/put/patch/delete/head, then
          // that is the HTTP method and the rest is the path.
          var methodMatch = _methods.firstMatch(method.name);
          if (methodMatch != null) {
            var rest = method.name.replaceAll(_methods, '');
            var restPath = ReCase(rest.isEmpty ? 'index' : rest).snakeCase
                .replaceAll(_rgxMultipleUnderscores, '_');
            httpMethod = methodMatch[1]!.toUpperCase();

            if (['index', 'by_id'].contains(restPath)) {
              parts.add('/');
            } else {
              parts.add(restPath);
            }
          }
          // If the name does NOT start with get/post/patch, etc. then
          // snake_case-ify the name, and add it to the list of segments.
          // If the name is index, though, add "/".
          else {
            if (method.name == 'index') {
              parts.add('/');
            } else {
              parts.add(
                ReCase(method.name).snakeCase
                    .replaceAll(_rgxMultipleUnderscores, '_'),
              );
            }
          }

          // Try to infer String, int, or double. We called
          // preInject() earlier, so we can figure out the types
          // of required parameters, and add those to the path.
          for (var p in injection.required) {
            if (p is List && p.length == 2 && p[0] is String && p[1] is Type) {
              var name = p[0] as String;
              var type = p[1] as Type;
              if (type == String) {
                parts.add(':$name');
              } else if (type == int) {
                parts.add('int:$name');
              } else if (type == double) {
                parts.add('double:$name');
              }
            }
          }

          path = parts.join('/');
          if (!path.startsWith('/')) path = '/$path';
        }

        routeMappings[name ?? ''] = routable.addRoute(
          httpMethod,
          path,
          handleContained(reflectedMethod, injection),
          middleware: middleware,
        );
      }
    };
  }

  /// Used to add additional routes or middlewares to the router from within
  /// a [Controller].
  ///
  /// ```dart
  /// @override
  /// FutureOr<void> configureRoutes(Routable routable) {
  ///   routable.all('*', myMiddleware);
  /// }
  /// ```
  FutureOr<void> configureRoutes(Routable routable) {}

  /// An HTTP verb at the start of a method name, as a whole word: `putUser`
  /// and `put` match, but `posts`, `getter` and `headers` do not.
  static final RegExp _methods = RegExp(
    r'^(get|post|put|patch|delete|head)(?=[A-Z0-9_]|$)',
  );
  static final RegExp _rgxMultipleUnderscores = RegExp(r'__+');

  /// Finds the [Expose] declaration for this class.
  ///
  /// The [expose] field takes precedence over a class-level `@Expose`
  /// annotation, which is only read when reflection is enabled.
  ///
  /// If [concreteOnly] is `false`, then if there is no actual
  /// [Expose], one will be automatically created.
  Expose? findExpose(Reflector reflector, {bool concreteOnly = false}) {
    var existing =
        expose ??
        (canReflect(reflector)
            ? reflector
                      .reflectClass(runtimeType)!
                      .annotations
                      .map((m) => m.reflectee)
                      .firstWhere((r) => r is Expose, orElse: () => null)
                  as Expose?
            : null);
    return existing ??
        (concreteOnly
            ? null
            : Expose(
                ReCase(runtimeType.toString()).snakeCase
                    .replaceAll('_controller', '')
                    .replaceAll('_ctrl', '')
                    .replaceAll(_rgxMultipleUnderscores, '_'),
              ));
  }
}
