library;

import 'dart:async';
import 'dart:collection' show HashMap;
import 'dart:convert';
import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_http_exception/angel3_http_exception.dart';
import 'package:angel3_route/angel3_route.dart';
import 'package:belatuk_combinator/belatuk_combinator.dart';
import 'package:http_parser/http_parser.dart';
import 'package:logging/logging.dart';
import 'package:mime/mime.dart';
import 'package:tuple/tuple.dart';
import 'controller.dart';
import 'env.dart';
import 'hooked_service.dart';
import 'request_context.dart';
import 'response_context.dart';
import 'routable.dart';
import 'service.dart';

//final RegExp _straySlashes = RegExp(r'(^/+)|(/+$)');

/// A function that configures an [Angel] server.
typedef AngelConfigurer = FutureOr<void> Function(Angel app);

/// A function that asynchronously generates a view from the given path and data.
typedef ViewGenerator = FutureOr<String> Function(String path,
    [Map<String, dynamic>? data]);

/// A function that handles error
typedef AngelErrorHandler = dynamic Function(
    AngelHttpException e, RequestContext req, ResponseContext res);

/// The default error handler for [Angel] server
Future<bool> _defaultErrorHandler(
    AngelHttpException e, RequestContext req, ResponseContext res) async {
  if (!req.accepts('text/html', strict: true) &&
      (req.accepts('application/json') ||
          req.accepts('application/javascript'))) {
    await res.json(e.toJson());
    return Future.value(false);
  } else {
    res.contentType = MediaType('text', 'html', {'charset': 'utf8'});
    res.statusCode = e.statusCode;
    res.write('<!DOCTYPE html><html><head><title>${e.message}</title>');
    res.write('</head><body><h1>${e.message}</h1><ul>');

    for (var error in e.errors) {
      res.write('<li>$error</li>');
    }

    res.write('</ul></body></html>');
    return Future.value(false);
  }
}

/// Default ROOT level logger
Logger _defaultLogger() {
  Logger logger = Logger('ROOT')
    ..onRecord.listen((rec) {
      if (rec.error == null) {
        print(rec.message);
      }

      if (rec.error != null) {
        var err = rec.error;
        if (err is AngelHttpException && err.statusCode != 500) return;
        print('${rec.message} \n');
        print(rec.error);
        if (rec.stackTrace != null) {
          print(rec.stackTrace);
        }
      }
    });

  return logger;
}

/// A powerful real-time/REST/MVC server class.
class Angel extends Routable {
  static Future<String> _noViewEngineConfigured(String view, [Map? data]) =>
      Future.value('No view engine has been configured yet.');

  final List<Angel> _children = [];
  final Map<
      String,
      Tuple4<List, Map<String, dynamic>, ParseResult<RouteResult>,
          MiddlewarePipeline>> handlerCache = HashMap();

  Router<RequestHandler>? _flattened;
  Angel? _parent;

  /// A global Map of converters that can transform responses bodies.
  final Map<String, Converter<List<int>, List<int>>> encoders = {};

  final Map<dynamic, InjectionRequest> _preContained = {};

  /// A [MimeTypeResolver] that can be used to specify the MIME types of files not known by `package:mime`.
  final MimeTypeResolver mimeTypeResolver = MimeTypeResolver();

  /// A middleware to inject a serialize on every request.
  FutureOr<String> Function(dynamic)? serializer;

  /// A [Map] of dependency data obtained via reflection.
  ///
  /// You may modify this [Map] yourself if you intend to avoid reflection entirely.
  Map<dynamic, InjectionRequest> get preContained => _preContained;

  /// Returns the [flatten]ed version of this router in production.
  Router<RequestHandler> get optimizedRouter => _flattened ?? this;

  /// Determines whether to allow HTTP request method overrides.
  bool allowMethodOverrides = true;

  /// All child application mounted on this instance.
  List<Angel> get children => List<Angel>.unmodifiable(_children);

  final Map<Pattern, Controller> _controllers = {};

  /// A set of [Controller] objects that have been loaded into the application.
  Map<Pattern, Controller> get controllers => _controllers;

  /// The [AngelEnvironment] in which the application is running.
  ///
  /// By default, it is automatically inferred.
  final AngelEnvironment environment;

  /// Returns the parent instance of this application, if any.
  Angel? get parent => _parent;

  /// Outputs diagnostics and debug messages.
  Logger _logger = _defaultLogger();

  Logger get logger => _logger;

  /// Assign a custom logger.
  /// Passing null will reset to default logger
  set logger(Logger? log) {
    _logger.clearListeners();

    _logger = log ?? _defaultLogger();
  }

  /// Plug-ins to be called right before server startup.
  ///
  /// If the server is never started, they will never be called.
  final List<AngelConfigurer> startupHooks = [];

  /// Plug-ins to be called right before server shutdown.
  ///
  /// If the server is never [close]d, they will never be called.
  final List<AngelConfigurer> shutdownHooks = [];

  /// Always run before responses are sent.
  ///
  /// These will only not run if a response's `willCloseItself` is set to `true`.
  final List<RequestHandler> responseFinalizers = [];

  /// A function that renders views.
  ///
  /// Called by [ResponseContext]@`render`.
  ViewGenerator? viewGenerator = _noViewEngineConfigured;

  /// The handler currently configured to run on [AngelHttpException]s.
  AngelErrorHandler errorHandler = _defaultErrorHandler;

  @override
  Route<RequestHandler> addRoute(
      String method, String path, RequestHandler handler,
      {Iterable<RequestHandler> middleware = const []}) {
    if (_flattened != null) {
      logger.warning(
          'WARNING: You added a route ($method $path) to the router, after it had been optimized.');
      logger.warning(
          'This route will be ignored, and no requests will ever reach it.');
    }

    return super.addRoute(method, path, handler, middleware: middleware);
  }

  @override
  SymlinkRoute<RequestHandler> mount(
      String path, Router<RequestHandler> router) {
    if (_flattened != null) {
      logger.warning(
          'WARNING: You added mounted a child router ($path) on the router, after it had been optimized.');
      logger.warning(
          'This route will be ignored, and no requests will ever reach it.');
    }

    if (router is Angel) {
      router._parent = this;
      _children.add(router);
    }

    return super.mount(path.toString(), router);
  }

  /// Loads some base dependencies into the service container.
  void bootstrapContainer() {
    if (runtimeType != Angel) {
      container.registerSingleton(this);
    }

    container.registerSingleton<Angel>(this);
    container.registerSingleton<Routable>(this);
    container.registerSingleton<Router>(this);
  }

  /// Shuts down the server, and closes any open [StreamController]s.
  ///
  /// The server will be **COMPLETELY DEFUNCT** after this operation!
  @override
  Future<void> close() {
    Future.forEach(services.values, (Service service) {
      service.close();
    });

    super.close();
    viewGenerator = _noViewEngineConfigured;
    _preContained.clear();
    handlerCache.clear();
    encoders.clear();
    _children.clear();
    //_parent = null;
    //logger = null;
    //_flattened = null;
    startupHooks.clear();
    shutdownHooks.clear();
    responseFinalizers.clear();
    return Future.value();
  }

  @override
  void dumpTree(
      {Function(String tree)? callback,
      String header = 'Dumping route tree:',
      String tab = '  ',
      bool showMatchers = false}) {
    if (environment.isProduction) {
      _flattened ??= flatten(this);

      _flattened!.dumpTree(
          callback: callback,
          header: header.isNotEmpty == true
              ? header
              : (environment.isProduction
                  ? 'Dumping flattened route tree:'
                  : 'Dumping route tree:'),
          tab: tab);
    } else {
      super.dumpTree(
          callback: callback,
          header: header.isNotEmpty == true
              ? header
              : (environment.isProduction
                  ? 'Dumping flattened route tree:'
                  : 'Dumping route tree:'),
          tab: tab);
    }
  }

  Future getHandlerResult(handler, RequestContext req, ResponseContext res) {
    if (handler is RequestHandler) {
      var result = handler(req, res);
      return getHandlerResult(result, req, res);
    }

    if (handler is Future) {
      return handler.then((result) => getHandlerResult(result, req, res));
    }

    if (handler is Function) {
      var result = runContained(handler, req, res);
      return getHandlerResult(result, req, res);
    }

    if (handler is Stream) {
      return getHandlerResult(handler.toList(), req, res);
    }

    return Future.value(handler);
  }

  /// Runs some [handler]. Returns `true` if request execution should continue.
  Future<bool> executeHandler(
      handler, RequestContext req, ResponseContext res) {
    return getHandlerResult(handler, req, res).then((result) {
      if (result == null) {
        return false;
      } else if (result is bool) {
        return result;
      } else if (result != null) {
        return res.serialize(result);
      } else {
        return res.isOpen;
      }
    });
  }

  /// Attempts to find a property by the given name within this application.
  dynamic findProperty(key) {
    if (configuration.containsKey(key)) return configuration[key];

    //return parent != null ? parent?.findProperty(key) : null;
    if (parent != null) {
      return parent?.findProperty(key);
    }

    return null;
  }

  /// Runs several optimizations, *if* [angelEnv.isProduction] is `true`.
  ///
  /// * Preprocesses all dependency injection, and eliminates the burden of reflecting handlers
  /// at run-time.
  /// * [flatten]s the route tree into a linear one.
  ///
  /// You may [force] the optimization to run, if you are not running in production.
  void optimizeForProduction({bool force = false}) {
    if (environment.isProduction || force == true) {
      _flattened ??= flatten(this);
      logger.info('Angel is running in production mode.');
    }
  }

  /// Run a function after injecting from service container.
  /// If this function has been reflected before, then
  /// the execution will be faster, as the injection requirements were stored beforehand.
  Future runContained(Function handler, RequestContext req, ResponseContext res,
      [Container? container]) {
    container ??= Container(EmptyReflector());
    return Future.sync(() {
      if (_preContained.containsKey(handler)) {
        return handleContained(handler, _preContained[handler]!, container)(
            req, res);
      }

      return runReflected(handler, req, res, container);
    });
  }

  /// Runs with DI, and *always* reflects. Prefer [runContained].
  Future runReflected(Function handler, RequestContext req, ResponseContext res,
      [Container? container]) {
    container ??=
        req.container ?? res.app?.container ?? Container(EmptyReflector());

    if (container.reflector is EmptyReflector) {
      throw ArgumentError("No `reflector` passed");
    }
    var h = handleContained(
        handler,
        _preContained[handler] = preInject(handler, container.reflector),
        container);
    return Future.sync(() => h(req, res));
    // return   closureMirror.apply(args).reflectee;
  }

  /// Applies an [AngelConfigurer] to this instance.
  Future configure(AngelConfigurer configurer) {
    return Future.sync(() => configurer(this));
  }

  /// Shorthand for using the [container] to instantiate, and then mount a [Controller].
  /// Returns the created controller.
  ///
  /// Just like [Container].make, in contexts without properly-reified generics (dev releases of Dart 2),
  /// provide a [type] argument as well.
  ///
  /// If you are on `Dart >=2.0.0`, simply call `mountController<T>()`.
  Future<T> mountController<T extends Controller>([Type? type]) {
    var controller = container.make<T>(type);
    return configure(controller.configureServer).then((_) => controller);
  }

  /// Shorthand for calling `all('*', handler)`.
  Route<RequestHandler?> fallback(RequestHandler handler) {
    return all('*', handler);
  }

  @override
  HookedService<Id, Data, T> use<Id, Data, T extends Service<Id, Data>>(
      String path, T service) {
    service.app = this;
    return super.use(path, service)..app = this;
  }

  static const String _reflectionErrorMessage =
      '${ContainerConst.defaultErrorMessage} $_reflectionInfo';

  static const String _reflectionInfo =
      'Features like controllers, constructor dependency injection, and `ioc` require reflection, '
      'and will not work without it.\n\n'
      'For more, see the documentation:\n'
      'https://docs.angel-dart.dev/guides/dependency-injection#enabling-dart-mirrors-or-other-reflection';

  Angel(
      {Reflector reflector =
          const ThrowingReflector(errorMessage: _reflectionErrorMessage),
      this.environment = angelEnv,
      Logger? logger,
      this.allowMethodOverrides = true,
      this.serializer,
      this.viewGenerator})
      : super(reflector) {
    // Override default logger
    if (logger != null) {
      this.logger = logger;
    }

    if (reflector is EmptyReflector || reflector is ThrowingReflector) {
      var msg =
          'No `reflector` was passed to the Angel constructor, so reflection will not be available.\n$_reflectionInfo';
      this.logger.warning(msg);
    }

    bootstrapContainer();
    viewGenerator ??= _noViewEngineConfigured;
    serializer ??= json.encode;
  }
}
