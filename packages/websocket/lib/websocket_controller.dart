part of 'server.dart';

/// Marks a method as available to WebSockets.
///
/// The method is found through the app's [Reflector], so it needs one that
/// can reflect upon the controller, such as `MirrorsReflector`. Without one,
/// register the handler with [WebSocketController.exposeWs] instead.
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

    ws.onConnection.listen((socket) async {
      if (!socket.request.container!.has<WebSocketContext>()) {
        socket.request.container!.registerSingleton<WebSocketContext>(socket);
      }

      await onConnect(socket);

      socket.onData.listen((data) => onData(data, socket));

      socket.onAction.listen((WebSocketAction action) async {
        try {
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

  /// Finds the `@ExposeWs` methods of this controller with [reflector], or
  /// none if it cannot reflect upon it, as the default [ThrowingReflector].
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

    for (var decl in clazz.declarations) {
      var function = decl.function;
      if (function == null ||
          decl.isStatic ||
          function.isGetter ||
          function.isSetter) {
        continue;
      }
      var expose =
          function.annotations
                  .map((a) => a.reflectee)
                  .firstWhere((r) => r is ExposeWs, orElse: () => null)
              as ExposeWs?;
      if (expose == null) continue;

      var method = instance.getField(decl.name).reflectee as Function;
      _exposed[expose.eventName] = (method, injectionFor(function));
    }
  }
}
