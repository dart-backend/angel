/// Server-side support for WebSockets.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_framework/http2.dart';
import 'package:belatuk_merge_map/belatuk_merge_map.dart';
import 'package:logging/logging.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/io.dart';

import 'angel3_websocket.dart';
import 'constants.dart';
export 'angel3_websocket.dart';

part 'websocket_context.dart';

part 'websocket_controller.dart';

typedef WebSocketResponseSerializer = String Function(dynamic data);

final RegExp _straySlashes = RegExp(r'(^/+)|(/+$)');

/// Broadcasts events from [HookedService]s, and handles incoming [WebSocketAction]s.
class AngelWebSocket {
  final List<WebSocketContext> _clients = <WebSocketContext>[];
  final List<String> _servicesAlreadyWired = [];

  // Broadcast, so that what no one listens to is not kept.
  final StreamController<WebSocketAction> _onAction =
      StreamController<WebSocketAction>.broadcast();
  final StreamController _onData = StreamController.broadcast();
  final StreamController<WebSocketContext> _onConnection =
      StreamController<WebSocketContext>.broadcast();
  final StreamController<WebSocketContext> _onDisconnect =
      StreamController<WebSocketContext>.broadcast();

  final Angel app;

  /// If this is not `true`, then all client-side service parameters will be
  /// discarded, other than `params['query']`.
  final bool allowClientParams;

  /// An optional whitelist of allowed client origins, or [:null:].
  ///
  /// A connection from another origin is refused before it is upgraded, with
  /// a `403 Forbidden`.
  final List<String> allowedOrigins;

  /// An optional whitelist of allowed client protocols, or [:null:].
  ///
  /// A connection that asks only for other protocols is refused before it is
  /// upgraded, with a `400 Bad Request`; of those it asks for, the first that
  /// is allowed is used.
  final List<String> allowedProtocols;

  /// If `true`, then clients can authenticate their WebSockets by sending a valid JWT.
  final bool allowAuth;

  /// Send error information across WebSockets, without including debug information..
  final bool sendErrors;

  /// A list of clients currently connected to this server via WebSockets.
  List<WebSocketContext> get clients => List.unmodifiable(_clients);

  /// Services that have already been hooked to fire socket events.
  List<String> get servicesAlreadyWired =>
      List.unmodifiable(_servicesAlreadyWired);

  Logger get _log => app.logger;

  /// Used to notify other nodes of an event's firing. Good for scaled applications.
  final StreamChannel<WebSocketEvent>? synchronizationChannel;

  /// Fired on any [WebSocketAction], to those listening when it comes.
  Stream<WebSocketAction> get onAction => _onAction.stream;

  /// Fired whenever a WebSocket sends data, to those listening when it comes.
  Stream get onData => _onData.stream;

  /// Fired on incoming connections.
  Stream<WebSocketContext> get onConnection => _onConnection.stream;

  /// Fired when a user disconnects.
  Stream<WebSocketContext> get onDisconnection => _onDisconnect.stream;

  /// Serializes data to WebSockets.
  WebSocketResponseSerializer? serializer;

  /// Deserializes data from WebSockets.
  Function? deserializer;

  AngelWebSocket(
    this.app, {
    this.sendErrors = false,
    this.allowClientParams = false,
    this.allowAuth = true,
    this.synchronizationChannel,
    this.serializer,
    this.deserializer,
    this.allowedOrigins = const [],
    this.allowedProtocols = const [],
  }) {
    serializer ??= json.encode;
    deserializer ??= (params) => params;
  }

  FutureOr<dynamic> Function(HookedServiceEvent<dynamic, dynamic, Service> e)
  serviceHook(String path) {
    return (HookedServiceEvent e) async {
      if (e.params['broadcast'] == false) return;

      var event = await transformEvent(e);
      event.eventName = '$path::${event.eventName}';

      dynamic filter(WebSocketContext socket) {
        if (e.service.configuration.containsKey('ws:filter')) {
          return e.service.configuration['ws:filter'](e, socket);
        } else if (e.params.containsKey('ws:filter')) {
          return e.params['ws:filter'](e, socket);
        } else {
          return true;
        }
      }

      await batchEvent(event, filter: filter);
    };
  }

  /// Slates an event to be dispatched.
  Future<void> batchEvent(
    WebSocketEvent event, {
    Function(WebSocketContext socket)? filter,
    bool notify = true,
  }) async {
    // Default implementation will just immediately fire events. Of a copy of
    // the clients, as one may disconnect while a filter runs.
    for (var client in List.of(_clients)) {
      dynamic result = true;
      if (filter != null) {
        result = await filter(client);
      }
      if (result == true && !client._closed) {
        client.channel.sink.add((serializer ?? json.encode)(event.toJson()));
      }
    }

    if (synchronizationChannel != null && notify != false) {
      synchronizationChannel!.sink.add(event);
    }
  }

  /// Returns a list of events yet to be sent.
  Future<List<WebSocketEvent>> getBatchedEvents() async => [];

  /// Responds to an incoming action on a WebSocket.
  ///
  /// Returns the event of a `create`, `modify`, `update` or `remove`, which
  /// [handleData] sends to the socket, unless the service broadcasts it, as
  /// a [HookedService] wired by [hookupService] does.
  Future handleAction(WebSocketAction action, WebSocketContext socket) async {
    var split = action.eventName!.split('::');

    if (split.length < 2) {
      socket.sendError(AngelHttpException.badRequest());
      return null;
    }

    var service = app.findService(split[0]);

    if (service == null) {
      socket.sendError(
        AngelHttpException.notFound(
          message: 'No service "${split[0]}" exists.',
        ),
      );
      return null;
    }

    var actionName = split[1];

    if (allowClientParams != true) {
      if (action.params['query'] is Map) {
        action.params = {'query': action.params['query']};
      } else {
        action.params = {};
      }
    }

    var params = mergeMap<String, dynamic>([
      (((deserializer ?? (params) => params)(action.params))
          as Map<String, dynamic>),
      {
        'provider': Providers.websocket,
        '__requestctx': socket.request,
        '__responsectx': socket.response,
      },
    ]);

    try {
      if (actionName == indexAction) {
        socket.send('${split[0]}::$indexedEvent', await service.index(params));
        return null;
      } else if (actionName == readAction) {
        socket.send(
          '${split[0]}::$readEvent',
          await service.read(action.id, params),
        );
        return null;
      } else if (actionName == createAction) {
        return WebSocketEvent(
          eventName: '${split[0]}::$createdEvent',
          data: await service.create(action.data, params),
        );
      } else if (actionName == modifyAction) {
        return WebSocketEvent(
          eventName: '${split[0]}::$modifiedEvent',
          data: await service.modify(action.id, action.data, params),
        );
      } else if (actionName == updateAction) {
        return WebSocketEvent(
          eventName: '${split[0]}::$updatedEvent',
          data: await service.update(action.id, action.data, params),
        );
      } else if (actionName == removeAction) {
        return WebSocketEvent(
          eventName: '${split[0]}::$removedEvent',
          data: await service.remove(action.id, params),
        );
      } else {
        socket.sendError(
          AngelHttpException.methodNotAllowed(
            message: 'Method Not Allowed: $actionName',
          ),
        );
        return null;
      }
    } catch (e, st) {
      _log.severe('Failed to handle the action "${action.eventName}"');
      catchError(e, st, socket);
    }
  }

  /// Authenticates a [WebSocketContext].
  ///
  /// The JWT is refused, as by `AngelAuth` over HTTP, if its signature is
  /// wrong, if it has expired, if `AngelAuth.enforceIp` and it was issued to
  /// another IP address, or if it names no user.
  Future handleAuth(WebSocketAction action, WebSocketContext socket) async {
    if (allowAuth == false) {
      socket.sendError(
        AngelHttpException.forbidden(
          message: 'Authentication over WebSockets is disabled.',
        ),
      );
      return;
    }
    if (action.eventName == authenticateAction &&
        action.params['query'] is Map &&
        action.params['query']['jwt'] is String) {
      try {
        var auth = socket.request.container!.make<AngelAuth>();
        var jwt = action.params['query']['jwt'] as String;
        var token = AuthToken.validate(jwt, auth.hmac);

        if (auth.enforceIp && socket.request.ip != token.ipAddress) {
          throw AngelHttpException.forbidden(
            message: 'JWT cannot be accessed from this IP address.',
          );
        }

        if (token.lifeSpan > -1) {
          var expiry = token.issuedAt.add(
            Duration(milliseconds: token.lifeSpan.toInt()),
          );
          if (!expiry.isAfter(DateTime.now())) {
            throw AngelHttpException.forbidden(message: 'Expired JWT.');
          }
        }

        Object? user = await auth.deserializer(token.userId);
        if (user == null) {
          throw AngelHttpException.notAuthenticated(
            message: 'The user of the JWT does not exist.',
          );
        }

        socket.request
          ..container!.registerSingleton<AuthToken>(token)
          ..container!.registerSingleton(user, as: user.runtimeType);
        socket._onAuthenticated.add(null);
        socket.send(authenticatedEvent, {
          'token': token.serialize(auth.hmac),
          'data': user,
        });
      } catch (e, st) {
        _log.severe('Authentication failed');
        catchError(e, st, socket);
      }
    } else {
      socket.sendError(
        AngelHttpException.badRequest(
          message: 'No JWT provided for authentication.',
        ),
      );
    }
  }

  /// Hooks a service up to have its events broadcasted.
  dynamic hookupService(Pattern path, HookedService service) {
    var localPath = path.toString();

    service.after([
      HookedServiceEvent.created,
      HookedServiceEvent.modified,
      HookedServiceEvent.updated,
      HookedServiceEvent.removed,
    ], serviceHook(localPath));
    _servicesAlreadyWired.add(localPath);
  }

  /// Whether the service at [path] broadcasts its events, of [hookupService].
  bool _broadcasts(String path) {
    var key = path.replaceAll(_straySlashes, '');
    return _servicesAlreadyWired.any(
      (p) => p.replaceAll(_straySlashes, '') == key,
    );
  }

  /// Runs before firing [onConnection].
  Future handleConnect(WebSocketContext socket) async {}

  /// Handles incoming data from a WebSocket.
  dynamic handleData(WebSocketContext socket, data) async {
    // Of a socket that has closed, whose streams are closed.
    if (socket._closed) return;
    try {
      socket._onData.add(data);
      var fromJson = json.decode(data.toString());
      if (fromJson is! Map) {
        throw AngelHttpException.badRequest(
          message: 'An action must be a JSON object.',
        );
      }
      var action = WebSocketAction.fromJson(fromJson);
      var eventName = action.eventName;

      if (eventName == null || eventName.isEmpty) {
        throw AngelHttpException.badRequest();
      }

      _onAction.add(action);
      socket._onAction.add(action);
      socket.on._add(eventName, fromJson['data']);

      if (eventName == authenticateAction) {
        await handleAuth(action, socket);
      }

      var split = eventName.split('::');
      if (split.length >= 2 && actions.contains(split[1])) {
        var event = await handleAction(action, socket);
        // Sent to the socket, as no hook broadcasts it.
        if (event is WebSocketEvent && !_broadcasts(split[0])) {
          socket.send(event.eventName!, event.data);
        }
      }
    } catch (e, st) {
      _log.severe('Invalid data');
      catchError(e, st, socket);
    }
  }

  void catchError(Object e, StackTrace st, WebSocketContext socket) {
    // Send an error
    if (e is AngelHttpException) {
      socket.sendError(e);
      app.logger.severe(e.message, e.error ?? e, e.stackTrace);
    } else if (sendErrors) {
      var err = AngelHttpException(
        message: e.toString(),
        stackTrace: st,
        errors: [st.toString()],
      );
      socket.sendError(err);
      app.logger.severe(err.message, e, st);
    } else {
      var err = AngelHttpException();
      socket.sendError(err);
      app.logger.severe(e.toString(), e, st);
    }
  }

  /// Transforms a [HookedServiceEvent], so that it can be broadcasted.
  Future<WebSocketEvent> transformEvent(HookedServiceEvent event) async {
    return WebSocketEvent(eventName: event.eventName, data: event.result);
  }

  /// Hooks any [HookedService]s that are not being broadcasted yet.
  void wireAllServices(Angel app) {
    for (var key in app.services.keys.where((x) {
      return !_servicesAlreadyWired.contains(x) &&
          app.services[x] is HookedService;
    })) {
      hookupService(key, app.services[key] as HookedService);
    }
  }

  /// Configures an [Angel] instance to listen for WebSocket connections.
  Future configureServer(Angel app) async {
    // As its own type, and, of a subclass, as AngelWebSocket too.
    app.container.registerSingleton(this, as: runtimeType);

    if (runtimeType != AngelWebSocket) {
      app.container.registerSingleton<AngelWebSocket>(this);
    }

    // Set up services
    wireAllServices(app);

    app.onService.listen((_) {
      wireAllServices(app);
    });

    if (synchronizationChannel != null) {
      synchronizationChannel?.stream.listen(
        (e) => batchEvent(e, notify: false),
        // E.g. a refused publish: logged, rather than uncaught.
        onError: (Object e, StackTrace st) =>
            app.logger.warning('WebSocket synchronization failed', e, st),
      );
    }

    app.shutdownHooks.add((_) => synchronizationChannel?.sink.close());
  }

  /// Handles an incoming [WebSocketContext], whose origin and protocol
  /// [handleRequest] has checked.
  Future<void> handleClient(WebSocketContext socket) async {
    _clients.add(socket);
    await handleConnect(socket);

    _onConnection.add(socket);

    socket.request.container?.registerSingleton<WebSocketContext>(socket);

    void disconnected() {
      if (!_clients.remove(socket)) return;
      socket._markClosed();
      _onDisconnect.add(socket);
    }

    socket.channel.stream.listen(
      (data) {
        _onData.add(data);
        handleData(socket, data);
      },
      onDone: disconnected,
      onError: (e) => disconnected(),
      cancelOnError: true,
    );
  }

  /// Throws a `403 Forbidden` if [allowedOrigins] does not allow the origin
  /// of [req].
  void _checkOrigin(RequestContext req) {
    var origin = req.headers?.value('origin');
    if (allowedOrigins.isNotEmpty && !allowedOrigins.contains(origin)) {
      throw AngelHttpException.forbidden(
        message:
            'WebSocket connections are not allowed from the origin "$origin".',
      );
    }
  }

  /// The first of the protocols [req] asks for that [allowedProtocols]
  /// allows, or `null` if it asks for none; throws a `400 Bad Request` if it
  /// asks only for others.
  String? _protocolOf(RequestContext req) {
    var requested = [
      for (var value in req.headers?['sec-websocket-protocol'] ?? <String>[])
        for (var protocol in value.split(','))
          if (protocol.trim().isNotEmpty) protocol.trim(),
    ];
    if (requested.isEmpty) return null;
    if (allowedProtocols.isEmpty) return requested.first;
    for (var protocol in requested) {
      if (allowedProtocols.contains(protocol)) return protocol;
    }
    throw AngelHttpException.badRequest(
      message:
          'Disallowed `sec-websocket-protocol` header "${requested.join(', ')}".',
    );
  }

  /// Handles an incoming HTTP request.
  ///
  /// Refuses, before it is upgraded, a connection from an origin that
  /// [allowedOrigins] does not allow, or that asks only for protocols that
  /// [allowedProtocols] does not allow. WebSockets over HTTP/2 are not
  /// supported; such a request is refused with a `501 Not Implemented`.
  Future<bool> handleRequest(RequestContext req, ResponseContext res) async {
    if (req is HttpRequestContext && res is HttpResponseContext) {
      if (!WebSocketTransformer.isUpgradeRequest(req.rawRequest!)) {
        throw AngelHttpException.badRequest();
      }
      _checkOrigin(req);
      var protocol = _protocolOf(req);

      res.detach();
      var ws = await WebSocketTransformer.upgrade(
        req.rawRequest!,
        protocolSelector: protocol == null ? null : (_) => protocol,
      );
      var channel = IOWebSocketChannel(ws);
      var socket = WebSocketContext(channel, req, res, serializer: serializer);
      scheduleMicrotask(() => handleClient(socket));
      return false;
    } else if (req is Http2RequestContext && res is Http2ResponseContext) {
      // HTTP/2 has no `Connection: upgrade`; WebSockets over it use an
      // extended CONNECT (RFC 8441), which this does not support.
      throw AngelHttpException(
        statusCode: 501,
        message:
            'WebSockets over HTTP/2 are not supported. Connect over HTTP/1.1.',
      );
    } else {
      throw ArgumentError(
        'Not an HTTP/1.1 or HTTP/2 RequestContext+ResponseContext pair: $req, $res',
      );
    }
  }
}
