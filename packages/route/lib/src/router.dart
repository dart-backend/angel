library;

import 'dart:async';

import 'package:belatuk_combinator/belatuk_combinator.dart';
import 'package:string_scanner/string_scanner.dart';

import '../string_util.dart';
import 'routing_exception.dart';
part 'grammar.dart';
part 'route.dart';
part 'routing_result.dart';
part 'symlink_route.dart';

//final RegExp _param = RegExp(r':([A-Za-z0-9_]+)(\((.+)\))?');
//final RegExp _rgxEnd = RegExp(r'\$+$');
//final RegExp _rgxStart = RegExp(r'^\^+');
//final RegExp _rgxStraySlashes =
//    RegExp(r'(^((\\+/)|(/))+)|(((\\+/)|(/))+$)');
//final RegExp _slashDollar = RegExp(r'/+\$');
final RegExp _straySlashes = RegExp(r'(^/+)|(/+$)');

/// An abstraction over complex [Route] trees. Use this instead of the raw API. :)
class Router<T> {
  final Map<String, Iterable<RoutingResult<T>>> _cache = {};
  int _maxCacheSize = 1024;

  //final List<_ChainedRouter> _chained = [];
  final List<T> _middleware = [];
  final Map<Pattern, Router<T>> _mounted = {};
  final List<Route<T>> _routes = [];
  bool _useCache = false;

  List<T> get middleware => List<T>.unmodifiable(_middleware);

  Map<Pattern, Router<T>> get mounted =>
      Map<Pattern, Router<T>>.unmodifiable(_mounted);

  /// All routes, with those of mounted routers joined to their mount path.
  ///
  /// The middleware of the link to a mounted router (see
  /// [SymlinkRoute.middleware]) and the router's own (e.g. from [group]) are
  /// prepended to the handlers of each of its routes, since only this
  /// router's [middleware] is applied separately when resolving.
  List<Route<T>> get routes {
    return _routes.fold<List<Route<T>>>([], (out, route) {
      if (route is SymlinkRoute<T>) {
        var middleware = [...route.middleware, ...route.router._middleware];
        for (var r in route.router.routes) {
          var joined = route.path.isEmpty ? r : Route.join(route, r);
          out.add(
            middleware.isEmpty
                ? joined
                : joined._withHandlers([...middleware, ...joined.handlers]),
          );
        }
        return out;
      } else {
        return out..add(route);
      }
    });
  }

  /// Provide a `root` to make this Router revolve around a pre-defined route.
  /// Not recommended.
  Router();

  /// Enables the use of a cache to eliminate the overhead of consecutive resolutions of the same path.
  ///
  /// The cache holds at most [maxSize] results, evicting the least recently
  /// used: its keys are request paths, so without a bound, distinct paths
  /// (e.g. `/users/1`, `/users/2`) would grow it indefinitely. A [maxSize]
  /// of 0 or less disables caching.
  void enableCache({int maxSize = 1024}) {
    _useCache = true;
    _maxCacheSize = maxSize;
  }

  /// The number of resolutions currently cached (see [enableCache]).
  int get cacheLength => _cache.length;

  /// Adds a route that responds to the given path
  /// for requests with the given method (case-insensitive).
  /// Provide '*' as the method to respond to all methods.
  Route<T> addRoute(
    String method,
    String path,
    T handler, {
    Iterable<T> middleware = const [],
  }) {
    if (_useCache == true) {
      throw StateError('Cannot add routes after caching is enabled.');
    }

    // Check if any mounted routers can match this
    final handlers = <T>[handler];

    //middleware ??= <T>[];

    handlers.insertAll(0, middleware);

    final route = Route<T>(path, method: method, handlers: handlers);
    _routes.add(route);
    return route;
  }

  /// Prepends the given [middleware] to any routes created
  /// by the resulting router.
  ///
  /// The resulting router can be chained, too.
  ChainedRouter<T> chain(Iterable<T> middleware) {
    var piped = ChainedRouter<T>(this, middleware);
    var route = SymlinkRoute<T>('/', piped);
    _routes.add(route);
    return piped;
  }

  /// Returns a [Router] with a duplicated version of this tree.
  Router<T> clone() {
    final router = Router<T>();
    final newMounted = Map<Pattern, Router<T>>.from(mounted);

    for (var route in routes) {
      if (route is! SymlinkRoute<T>) {
        router._routes.add(route.clone());
      } else {
        final newRouter = route.router.clone();
        newMounted[route.path] = newRouter;
        final symlink = SymlinkRoute<T>(route.path, newRouter);
        router._routes.add(symlink);
      }
    }

    return router.._mounted.addAll(newMounted);
  }

  /// Creates a visual representation of the route hierarchy and
  /// passes it to a callback. If none is provided, `print` is called.
  void dumpTree({
    Function(String tree)? callback,
    String header = 'Dumping route tree:',
    String tab = '  ',
  }) {
    final buf = StringBuffer();
    var tabs = 0;

    if (header.isNotEmpty) {
      buf.writeln(header);
    }

    buf.writeln('<root>');

    void indent() {
      for (var i = 0; i < tabs; i++) {
        buf.write(tab);
      }
    }

    void dumpRouter(Router router) {
      indent();
      tabs++;

      for (var route in router.routes) {
        indent();
        buf.write('- ');
        if (route is! SymlinkRoute) buf.write('${route.method} ');
        buf.write(route.path.isNotEmpty ? route.path : '/');

        if (route is SymlinkRoute<T>) {
          buf.writeln();
          dumpRouter(route.router);
        } else {
          buf.writeln(' => ${route.handlers.length} handler(s)');
        }
      }

      tabs--;
    }

    dumpRouter(this);

    (callback ?? print)(buf.toString());
  }

  /// Creates a route, and allows you to add child routes to it
  /// via a [Router] instance.
  ///
  /// Returns the created route.
  /// You can also register middleware within the router.
  SymlinkRoute<T> group(
    String path,
    void Function(Router<T> router) callback, {
    Iterable<T> middleware = const [],
    String name = '',
  }) {
    final router = Router<T>().._middleware.addAll(middleware);
    callback(router);
    return mount(path, router)..name = name;
  }

  /// Asynchronous equivalent of [group].
  Future<SymlinkRoute<T>> groupAsync(
    String path,
    FutureOr<void> Function(Router<T> router) callback, {
    Iterable<T> middleware = const [],
    String name = '',
  }) async {
    final router = Router<T>().._middleware.addAll(middleware);
    await callback(router);
    return mount(path, router)..name = name;
  }

  /// Generates a URI string based on the given input.
  /// Handy when you have named routes.
  ///
  /// Each item in `linkParams` should be a [Route],
  /// `String` or `Map<String, dynamic>`.
  ///
  /// Strings should be route names, namespaces, or paths.
  /// Maps should be parameters, which will be filled
  /// into the previous route.
  ///
  /// Paths and segments should correspond to the way
  /// you declared them.
  ///
  /// For example, if you declared a route group on
  /// `'users/:id'`, it would not be resolved if you
  /// passed `'users'` in [linkParams].
  ///
  /// Leading and trailing slashes are automatically
  /// removed.
  ///
  /// Set [absolute] to `true` to insert a forward slash
  /// before the generated path.
  ///
  /// Example:
  /// ```dart
  /// router.navigate(['users/:id', {'id': '1337'}, 'profile']);
  /// ```
  String navigate(Iterable linkParams, {bool absolute = true}) {
    final segments = <String>[];
    Router search = this;
    Route? lastRoute;

    for (final param in linkParams) {
      var resolved = false;

      if (param is String) {
        // Search by name
        for (var route in search.routes) {
          if (route.name == param) {
            segments.add(route.path.replaceAll(_straySlashes, ''));
            lastRoute = route;

            if (route is SymlinkRoute<T>) {
              search = route.router;
            }

            resolved = true;
            break;
          }
        }

        // Search by path
        if (!resolved) {
          var scanner = SpanScanner(param.replaceAll(_straySlashes, ''));
          for (var route in search.routes) {
            var pos = scanner.position;
            var parseResult = _tryParse(route.parser, scanner);
            if (parseResult != null) {
              if (parseResult.successful && scanner.isDone) {
                segments.add(route.path.replaceAll(_straySlashes, ''));
                lastRoute = route;

                if (route is SymlinkRoute<T>) {
                  search = route.router;
                }

                resolved = true;
                break;
              } else {
                scanner.position = pos;
              }
            } else {
              scanner.position = pos;
            }
          }
        }

        if (!resolved) {
          throw RoutingException(
            'Cannot resolve route for link param "$param".',
          );
        }
      } else if (param is Route) {
        segments.add(param.path.replaceAll(_straySlashes, ''));
      } else if (param is Map<String, dynamic>) {
        if (lastRoute == null) {
          throw RoutingException(
            'Maps in link params must be preceded by a Route or String.',
          );
        } else {
          segments.removeLast();
          segments.add(lastRoute.makeUri(param).replaceAll(_straySlashes, ''));
        }
      } else {
        throw RoutingException(
          'Link param $param is not Route, String, or Map<String, dynamic>.',
        );
      }
    }

    return absolute
        ? '/${segments.join('/').replaceAll(_straySlashes, '')}'
        : segments.join('/');
  }

  /// Finds the first [Route] that matches the given path,
  /// with the given method.
  bool resolve(
    String absolute,
    String relative,
    List<RoutingResult<T?>> out, {
    String method = 'GET',
    bool strip = true,
  }) {
    final cleanRelative = strip == false
        ? relative
        : stripStraySlashes(relative);
    var scanner = SpanScanner(cleanRelative);

    bool crawl(Router<T> r) {
      var success = false;

      for (var route in r.routes) {
        var pos = scanner.position;

        if (route is SymlinkRoute<T>) {
          if (route.parser != null) {
            if (_tryParse(route.parser, scanner)?.successful == true) {
              var s = crawl(route.router);
              if (s) success = true;
            }
          }

          scanner.position = pos;
        } else if (route.method == '*' || route.method == method) {
          var parseResult = _tryParse(route.parser, scanner);
          if (parseResult != null) {
            if (parseResult.successful && scanner.isDone) {
              var tailResult = parseResult.value?.tail ?? '';
              //print(tailResult);
              var result = RoutingResult<T>(
                parseResult: parseResult,
                params: parseResult.value!.params,
                shallowRoute: route,
                shallowRouter: this,
                tail: tailResult + scanner.rest,
              );
              out.add(result);
              success = true;
            }
          }
          scanner.position = pos;
        }
      }

      return success;
    }

    return crawl(this);
  }

  /// Parses with [parser], treating a path whose parameters cannot be read
  /// (see [_NoMatch]) as no match.
  static ParseResult<RouteResult>? _tryParse(
    Parser<RouteResult>? parser,
    SpanScanner scanner,
  ) {
    try {
      return parser?.parse(scanner);
    } on _NoMatch {
      return null;
    }
  }

  /// Returns the result of [resolve] with [path] passed as
  /// both `absolute` and `relative`.
  Iterable<RoutingResult<T>> resolveAbsolute(
    String path, {
    String method = 'GET',
    bool strip = true,
  }) => resolveAll(path, path, method: method, strip: strip);

  /// Finds every possible [Route] that matches the given path,
  /// with the given method.
  Iterable<RoutingResult<T>> resolveAll(
    String absolute,
    String relative, {
    String method = 'GET',
    bool strip = true,
  }) {
    if (_useCache && _maxCacheSize > 0) {
      var key = '$method\u0000$strip\u0000$absolute\u0000$relative';
      // Re-inserting moves the entry to the end, keeping eviction LRU.
      var results =
          _cache.remove(key) ??
          _resolveAll(absolute, relative, method: method, strip: strip);
      while (_cache.length >= _maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }
      return _cache[key] = results;
    }

    return _resolveAll(absolute, relative, method: method, strip: strip);
  }

  Iterable<RoutingResult<T>> _resolveAll(
    String absolute,
    String relative, {
    String method = 'GET',
    bool strip = true,
  }) {
    var results = <RoutingResult<T>>[];
    resolve(absolute, relative, results, method: method, strip: strip);

    // _printDebug(
    //    'Results of $method "/${absolute.replaceAll(_straySlashes, '')}": ${results.map((r) => r.route).toList()}');
    return results;
  }

  /// Incorporates another [Router]'s routes into this one's.
  SymlinkRoute<T> mount(String path, Router<T> router) =>
      _mount(SymlinkRoute<T>(path, router));

  SymlinkRoute<T> _mount(SymlinkRoute<T> route) {
    _mounted[route.path] = route.router;
    _routes.add(route);
    return route;
  }

  /// Adds a route that responds to any request matching the given path.
  Route<T> all(String path, T handler, {Iterable<T> middleware = const []}) {
    return addRoute('*', path, handler, middleware: middleware);
  }

  /// Adds a route that responds to a DELETE request.
  Route<T> delete(String path, T handler, {Iterable<T> middleware = const []}) {
    return addRoute('DELETE', path, handler, middleware: middleware);
  }

  /// Adds a route that responds to a GET request.
  Route<T> get(String path, T handler, {Iterable<T> middleware = const []}) {
    return addRoute('GET', path, handler, middleware: middleware);
  }

  /// Adds a route that responds to a HEAD request.
  Route<T> head(String path, T handler, {Iterable<T> middleware = const []}) {
    return addRoute('HEAD', path, handler, middleware: middleware);
  }

  /// Adds a route that responds to a OPTIONS request.
  Route<T> options(
    String path,
    T handler, {
    Iterable<T> middleware = const {},
  }) {
    return addRoute('OPTIONS', path, handler, middleware: middleware);
  }

  /// Adds a route that responds to a POST request.
  Route<T> post(String path, T handler, {Iterable<T> middleware = const []}) {
    return addRoute('POST', path, handler, middleware: middleware);
  }

  /// Adds a route that responds to a PATCH request.
  Route<T> patch(String path, T handler, {Iterable<T> middleware = const []}) {
    return addRoute('PATCH', path, handler, middleware: middleware);
  }

  /// Adds a route that responds to a PUT request.
  Route put(String path, T handler, {Iterable<T> middleware = const []}) {
    return addRoute('PUT', path, handler, middleware: middleware);
  }
}

class ChainedRouter<T> extends Router<T> {
  final List<T> _handlers = <T>[];
  Router _root;

  ChainedRouter.empty() : _root = Router();

  ChainedRouter(this._root, Iterable<T> middleware) {
    _handlers.addAll(middleware);
  }

  @override
  Route<T> addRoute(
    String method,
    String path,
    handler, {
    Iterable<T> middleware = const [],
  }) {
    var route = super.addRoute(
      method,
      path,
      handler,
      middleware: [..._handlers, ...middleware],
    );
    //_root._routes.add(route);
    return route;
  }

  @override
  SymlinkRoute<T> group(
    String path,
    void Function(Router<T> router) callback, {
    Iterable<T> middleware = const [],
    String? name,
  }) {
    final router = ChainedRouter<T>(_root, [..._handlers, ...middleware]);
    callback(router);
    // Its routes already include the chained handlers.
    return super.mount(path, router)..name = name;
  }

  @override
  Future<SymlinkRoute<T>> groupAsync(
    String path,
    FutureOr<void> Function(Router<T> router) callback, {
    Iterable<T> middleware = const [],
    String? name,
  }) async {
    final router = ChainedRouter<T>(_root, [..._handlers, ...middleware]);
    await callback(router);
    // Its routes already include the chained handlers.
    return super.mount(path, router)..name = name;
  }

  /// Mounts [router] with the chained handlers running before its routes,
  /// at this mount only: [router] itself is not changed.
  @override
  SymlinkRoute<T> mount(String path, Router<T> router) =>
      _mount(SymlinkRoute<T>(path, router, middleware: _handlers));

  @override
  ChainedRouter<T> chain(Iterable<T> middleware) {
    final piped = ChainedRouter<T>.empty().._root = _root;
    piped._handlers.addAll([..._handlers, ...middleware]);
    var route = SymlinkRoute<T>('/', piped);
    _routes.add(route);
    return piped;
  }
}

/// Optimizes a router by condensing all its routes into one level.
Router<T> flatten<T>(Router<T> router) {
  var flattened = Router<T>();

  for (var route in router.routes) {
    if (route is SymlinkRoute<T>) {
      var base = route.path.replaceAll(_straySlashes, '');
      var child = flatten(route.router);

      for (var route in child.routes) {
        var path = route.path.replaceAll(_straySlashes, '');
        var joined = '$base/$path'.replaceAll(_straySlashes, '');
        flattened.addRoute(
          route.method,
          joined.replaceAll(_straySlashes, ''),
          route.handlers.last,
          middleware: route.handlers.take(route.handlers.length - 1).toList(),
        );
      }
    } else {
      flattened.addRoute(
        route.method,
        route.path,
        route.handlers.last,
        middleware: route.handlers.take(route.handlers.length - 1).toList(),
      );
    }
  }

  return flattened..enableCache();
}
