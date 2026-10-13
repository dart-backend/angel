part of 'server.dart';

/// Marks a method as available to WebSockets.
class ExposeWs {
  final String eventName;

  const ExposeWs(this.eventName);
}

/// A special controller that also supports WebSockets.
class WebSocketController extends Controller {
  /// The plug-in instance powering this controller.
  final AngelWebSocket ws;

  /// The `@ExposeWs` handlers, by event name, with what they inject. These are
  /// found with `dart:mirrors`, so they run without the app's reflector.
  final Map<String, (Function, InjectionRequest)> _handlers = {};

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

    var instanceMirror = reflect(this);
    var classMirror = reflectClass(runtimeType);
    classMirror.instanceMembers.forEach((sym, mirror) {
      if (mirror.isRegularMethod) {
        var exposeMirror = mirror.metadata.firstWhereOrNull(
          (mirror) => mirror.reflectee is ExposeWs,
        );

        if (exposeMirror != null) {
          var exposeWs = exposeMirror.reflectee as ExposeWs;
          _handlers[exposeWs.eventName] = (
            instanceMirror.getField(sym).reflectee as Function,
            injectionFromParameters(mirror.parameters.map(_injectable)),
          );
        }
      }
    });

    ws.onConnection.listen((socket) async {
      if (!socket.request.container!.has<WebSocketContext>()) {
        socket.request.container!.registerSingleton<WebSocketContext>(socket);
      }

      await onConnect(socket);

      socket.onData.listen((data) => onData(data, socket));

      socket.onAction.listen((WebSocketAction action) async {
        var container = socket.request.container!.createChild();
        container.registerSingleton<WebSocketAction>(action);

        try {
          await onAction(action, socket);

          var handler = _handlers[action.eventName];
          if (handler != null) {
            var (fn, injection) = handler;
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

  static InjectableParameter _injectable(ParameterMirror parameter) {
    return InjectableParameter(
      name: MirrorSystem.getName(parameter.simpleName),
      type: parameter.type.hasReflectedType
          ? parameter.type.reflectedType
          : dynamic,
      isRequired: !parameter.isOptional,
      isNamed: parameter.isNamed,
      hasDefaultValue: parameter.hasDefaultValue,
      annotation:
          parameter.metadata
                  .firstWhereOrNull((m) => m.reflectee is Parameter)
                  ?.reflectee
              as Parameter?,
    );
  }
}
