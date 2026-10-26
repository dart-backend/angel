part of 'server.dart';

/// Marks a method as available to WebSockets, and not as an HTTP route.
///
/// The method is found through the app's [Reflector], so it needs one that
/// can reflect upon the controller, such as a `StaticReflector` of the data
/// `angel3_container_generator` generates for it; one of a base controller is
/// found if the reflector describes the base class too. Without one, register
/// the handler with [WebSocketController.exposeWs] instead.
class ExposeWs {
  final String eventName;

  const ExposeWs(this.eventName);
}

/// A handler of a [WebSocketAction], given to [WebSocketController.exposeWs].
typedef WebSocketActionHandler = FutureOr<dynamic> Function(
  WebSocketAction action,
  WebSocketContext socket,
);

/// A special controller that also supports WebSockets.
///
/// Its handlers of actions, by event name, are those registered with
/// [exposeWs], in [configureWs], and the `@ExposeWs` methods the app's
/// [Reflector] finds.
class WebSocketController extends Controller {
  /// The plug-in instance powering this controller.
  final AngelWebSocket ws;

  /// The handlers of [exposeWs], by event name.
  final Map<String, WebSocketActionHandler> _handlers = {};

  /// The `@ExposeWs` methods, by event name, with what they inject.
  final Map<String, (Function, InjectionRequest)> _exposed = {};

  WebSocketController(this.ws) : super();

  /// Sends an event to all clients.
  void broadcast(
    String eventName,
    data, {
    Function(WebSocketContext socket)? filter,
  }) {
    ws.batchEvent(
      WebSocketEvent(eventName: eventName, data: data),
      filter: filter,
    );
  }

  /// Handles the actions of [eventName] with [handler], in place of an
  /// `@ExposeWs` method of that name. Needs no reflection.
  void exposeWs(String eventName, WebSocketActionHandler handler) {
    _handlers[eventName] = handler;
  }

  /// Registers the handlers of actions with [exposeWs]. Runs in
  /// [configureServer].
  FutureOr<void> configureWs() {}

  /// Fired on new connections.
  dynamic onConnect(WebSocketContext socket) {}

  /// Fired on disconnections.
  dynamic onDisconnect(WebSocketContext socket) {}

  /// Fired on all incoming actions.
  dynamic onAction(WebSocketAction action, WebSocketContext socket) async {}

  /// Fired on arbitrary incoming data.
  dynamic onData(dynamic data, WebSocketContext socket) {}

  @override
  Future configureServer(Angel app) async {
    if (findExpose(app.container.reflector) != null) {
      await super.configureServer(app);
    }

    _findExposed(app.container.reflector);
    await configureWs();

    ws.onConnection.listen((socket) {
      if (!socket.request.container!.has<WebSocketContext>()) {
        socket.request.container!.registerSingleton<WebSocketContext>(socket);
      }

      // The streams of the socket are listened to before [onConnect] runs,
      // as they are broadcast streams, which keep no event for later; what
      // comes meanwhile is handled once it has run.
      var connected = Future.sync(() => onConnect(socket))
          .catchError((Object e, StackTrace st) {
            ws.catchError(e, st, socket);
          });

      socket.onData.listen((data) async {
        await connected;
        return onData(data, socket);
      });

      socket.onAction.listen((WebSocketAction action) async {
        try {
          await connected;
          await onAction(action, socket);

          var handler = _handlers[action.eventName];
          if (handler != null) return await handler(action, socket);

          var exposed = _exposed[action.eventName];
          if (exposed != null) {
            var container = socket.request.container!.createChild();
            container.registerSingleton<WebSocketAction>(action);
            var (fn, injection) = exposed;
            return await handleContained(fn, injection, container)(
              socket.request,
              socket.response,
            );
          }
        } catch (e, st) {
          ws.catchError(e, st, socket);
        }
      });
    });

    ws.onDisconnection.listen(onDisconnect);
  }

  /// The methods of [WebSocketController] that a subclass overrides, which
  /// are not routes.
  static const _hooks = {
    'broadcast',
    'exposeWs',
    'configureWs',
    'onConnect',
    'onDisconnect',
    'onAction',
    'onData',
  };

  /// Keeps the `@ExposeWs` methods and the hooks of this controller, as
  /// [onConnect], off its HTTP routes.
  @override
  bool routesMethod(ReflectedDeclaration declaration) =>
      !_hooks.contains(declaration.name) &&
      !(declaration.function?.annotations.any((a) => a.reflectee is ExposeWs) ??
          false);

  /// Finds the `@ExposeWs` methods of this controller with [reflector], or
  /// none if it cannot reflect upon it, as the default [ThrowingReflector]:
  /// those it declares, and those it inherits from the superclasses the
  /// reflector describes, unless it overrides them.
  void _findExposed(Reflector reflector) {
    if (reflector is ThrowingReflector) return;
    ReflectedClass? clazz;
    ReflectedInstance? instance;
    try {
      clazz = reflector.reflectClass(runtimeType);
      instance = reflector.reflectInstance(this);
    } catch (_) {
      // A reflector without information about this class.
      return;
    }
    if (clazz == null || instance == null) return;

    var classes = <ReflectedClass>[clazz];
    for (var type in clazz.supertypes) {
      try {
        var superclass = reflector.reflectClass(type);
        if (superclass != null) classes.add(superclass);
      } catch (_) {
        // A superclass the reflector does not describe.
      }
    }

    // The names a class nearer this one declares, which hide those further.
    var declared = <String>{};
    for (var c in classes) {
      for (var decl in c.declarations) {
        var function = decl.function;
        if (function == null ||
            decl.isStatic ||
            function.isGetter ||
            function.isSetter ||
            !declared.add(decl.name)) {
          continue;
        }
        var expose =
            function.annotations
                    .map((a) => a.reflectee)
                    .firstWhere((r) => r is ExposeWs, orElse: () => null)
                as ExposeWs?;
        if (expose == null || _exposed.containsKey(expose.eventName)) continue;

        var method = instance.getField(decl.name).reflectee as Function;
        _exposed[expose.eventName] = (method, injectionFor(function));
      }
    }
  }
}
