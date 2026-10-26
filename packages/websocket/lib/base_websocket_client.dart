import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:angel3_client/angel3_client.dart';
import 'package:angel3_client/base_angel_client.dart';
import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'angel3_websocket.dart';
import 'constants.dart';

final RegExp _straySlashes = RegExp(r'(^/)|(/+$)');

/// An [Angel] client that operates across WebSockets.
///
/// Its streams are broadcast streams: an event is given to those listening
/// when it comes, and is not kept for those who listen later.
abstract class BaseWebSocketClient extends BaseAngelClient {
  Duration? _reconnectInterval;
  WebSocketChannel? _socket;
  final Queue<WebSocketAction> _queue = Queue<WebSocketAction>();
  final List<WebSocketsService> _services = [];

  /// Whether [close] was called, after which the client does not reconnect.
  bool _closed = false;

  /// Whether the client is trying to reconnect, of [_reconnect].
  bool _reconnecting = false;

  final StreamController _onData = StreamController.broadcast();
  final StreamController<WebSocketEvent> _onAllEvents =
      StreamController<WebSocketEvent>.broadcast();
  final StreamController<AngelAuthResult> _onAuthenticated =
      StreamController<AngelAuthResult>.broadcast();
  final StreamController<AngelHttpException> _onError =
      StreamController<AngelHttpException>.broadcast();
  final StreamController<Map<String, WebSocketEvent>> _onServiceEvent =
      StreamController<Map<String, WebSocketEvent>>.broadcast();
  final StreamController<WebSocketChannelException>
  _onWebSocketChannelException =
      StreamController<WebSocketChannelException>.broadcast();

  /// Use this to handle events that are not standard.
  final WebSocketExtraneousEventHandler on = WebSocketExtraneousEventHandler();

  /// Fired on all events.
  Stream<WebSocketEvent> get onAllEvents => _onAllEvents.stream;

  /// Fired whenever a WebSocket is successfully authenticated.
  @override
  Stream<AngelAuthResult> get onAuthenticated => _onAuthenticated.stream;

  /// A broadcast stream of data coming from the [socket].
  ///
  /// Mostly just for internal use.
  Stream get onData => _onData.stream;

  /// Fired on errors.
  Stream<AngelHttpException> get onError => _onError.stream;

  /// Fired whenever an event is fired by a service.
  Stream<Map<String, WebSocketEvent>> get onServiceEvent =>
      _onServiceEvent.stream;

  /// Fired on [WebSocketChannelException]s.
  Stream<WebSocketChannelException> get onWebSocketChannelException =>
      _onWebSocketChannelException.stream;

  /// The [WebSocketChannel] underneath this instance.
  WebSocketChannel? get socket => _socket;

  /// If `true` (default), then the client will automatically try to reconnect to the server
  /// if the socket closes, unless it was closed with [close].
  final bool reconnectOnClose;

  /// The amount of time to wait between reconnect attempts. Default: 10 seconds.
  Duration? get reconnectInterval => _reconnectInterval;

  Uri? _wsUri;

  /// The [Uri] to which a websocket should point.
  Uri get websocketUri => _wsUri ??= _toWsUri(baseUrl);

  static Uri _toWsUri(Uri u) {
    if (u.hasScheme) {
      if (u.scheme == 'http') {
        return u.replace(scheme: 'ws');
      } else if (u.scheme == 'https') {
        return u.replace(scheme: 'wss');
      } else {
        return u;
      }
    } else {
      return _toWsUri(u.replace(scheme: Uri.base.scheme));
    }
  }

  BaseWebSocketClient(
    super.client,
    super.baseUrl, {
    this.reconnectOnClose = true,
    Duration? reconnectInterval,
  }) {
    _reconnectInterval = reconnectInterval ?? Duration(seconds: 10);
  }

  /// Closes the socket and the services of this client, which does not
  /// reconnect after it.
  @override
  Future close() async {
    if (_closed) return;
    _closed = true;
    on._close();
    for (var service in _services) {
      await service.close();
    }
    await _socket?.sink.close(status.normalClosure);
    _socket = null;
    await _onData.close();
    await _onAllEvents.close();
    await _onAuthenticated.close();
    await _onError.close();
    await _onServiceEvent.close();
    await _onWebSocketChannelException.close();
  }

  /// Connects the WebSocket. [timeout] is optional.
  ///
  /// The actions sent before it is connected are sent once it is. Throws the
  /// error of the connection, or a [TimeoutException] after [timeout].
  Future<WebSocketChannel?> connect({Duration? timeout}) async {
    if (_closed) throw StateError('The client has been closed.');
    // Not a second socket, whose events would come twice.
    if (_socket != null) return _socket;

    var connecting = getConnectedWebSocket();
    WebSocketChannel socket;
    if (timeout == null) {
      socket = await connecting;
    } else {
      socket = await connecting.timeout(
        timeout,
        onTimeout: () {
          // Closed if it connects after all.
          connecting.then((s) => s.sink.close(), onError: (_) {});
          throw TimeoutException(
            'WebSocket connection exceeded timeout of ${timeout.inMilliseconds} ms',
            timeout,
          );
        },
      );
    }

    if (_closed) {
      await socket.sink.close(status.normalClosure);
      throw StateError('The client has been closed.');
    }

    _socket = socket;
    listen();
    while (_queue.isNotEmpty) {
      socket.sink.add(serialize(_queue.removeFirst()));
    }
    return socket;
  }

  /// Tries to connect again, one attempt at a time, every
  /// [reconnectInterval], until it connects or the client is closed.
  Future<void> _reconnect() async {
    if (_reconnecting) return;
    _reconnecting = true;
    try {
      while (!_closed && _socket == null) {
        await Future.delayed(reconnectInterval!);
        if (_closed) return;
        try {
          await connect(timeout: reconnectInterval);
        } catch (_) {
          // Again, after the interval.
        }
      }
    } finally {
      _reconnecting = false;
    }
  }

  /// Returns a new [WebSocketChannel], ready to be listened on.
  ///
  /// This should be overriden by child classes, **NOT** [connect].
  Future<WebSocketChannel> getConnectedWebSocket();

  /// Keeps [service], which [close] closes, as a [Service] of [Id] and
  /// [Data].
  ///
  /// Throws an [ArgumentError] if [Data] is not nullable: the methods of a
  /// [WebSocketsService] return `null`, as their results come as events.
  @protected
  Service<Id, Data> addService<Id, Data>(WebSocketsService service) {
    if (service is! Service<Id, Data>) {
      throw ArgumentError(
        'The data of a WebSocket service is given as events, and its methods '
        'return null, so its type must be nullable: use '
        'service<$Id, $Data?>(...), not service<$Id, $Data>(...).',
      );
    }
    _services.add(service);
    return service as Service<Id, Data>;
  }

  @override
  Service<Id, Data> service<Id, Data>(
    String path, {
    Type? type,
    AngelDeserializer<Data>? deserializer,
  }) {
    var uri = path.toString().replaceAll(_straySlashes, '');
    return addService<Id, Data>(
      WebSocketsService<Id, Data>(
        socket,
        this,
        uri,
        deserializer: deserializer,
      ),
    );
  }

  /// Starts listening for data.
  void listen() {
    var socket = _socket;
    socket?.stream.listen(
      (data) {
        if (_closed) return;
        _onData.add(data);

        if (data is WebSocketChannelException) {
          _onWebSocketChannelException.add(data);
        } else if (data is String) {
          Object? jsons;
          try {
            jsons = json.decode(data);
          } on FormatException {
            // Not an event.
            return;
          }

          if (jsons is Map) {
            var event = WebSocketEvent.fromJson(jsons);
            var name = event.eventName;

            if (name != null && name.isNotEmpty) {
              _onAllEvents.add(event);
              on._add(name, event);
            }

            if (name == errorEvent) {
              var data = event.data;
              _onError.add(
                AngelHttpException.fromMap(data is Map ? data : const {}),
              );
            } else if (name == authenticatedEvent) {
              var authResult = AngelAuthResult.fromMap(event.data as Map?);
              _onAuthenticated.add(authResult);
            } else if (name != null && name.isNotEmpty) {
              var split = name
                  .split('::')
                  .where((str) => str.isNotEmpty)
                  .toList();

              if (split.length >= 2) {
                var serviceName = split[0], eventName = split[1];
                // A new event, as [event] has gone to the other streams.
                _onServiceEvent.add({
                  serviceName: WebSocketEvent(
                    eventName: eventName,
                    data: event.data,
                  ),
                });
              }
            }
          }
        }
      },
      cancelOnError: true,
      onDone: () {
        if (!identical(_socket, socket)) return;
        _socket = null;
        if (reconnectOnClose == true && !_closed) _reconnect();
      },
    );
  }

  /// Serializes data to JSON.
  dynamic serialize(dynamic x) => json.encode(x);

  /// Sends the given [action] on the [socket], or once it is connected.
  void sendAction(WebSocketAction action) {
    var socket = _socket;
    if (socket == null) {
      _queue.addLast(action);
    } else {
      socket.sink.add(serialize(action));
    }
  }

  /// Attempts to authenticate a WebSocket, using a valid JWT.
  void authenticateViaJwt(String? jwt) {
    sendAction(
      WebSocketAction(
        eventName: authenticateAction,
        params: {
          'query': {'jwt': jwt},
        },
      ),
    );
  }
}

/// A [Service] that asynchronously interacts with the server.
///
/// Its streams are broadcast streams, as those of [BaseWebSocketClient].
class WebSocketsService<Id, Data> extends Service<Id, Data?> {
  /// The [BaseWebSocketClient] that spawned this service.
  @override
  final BaseWebSocketClient app;

  /// Used to deserialize JSON into typed data.
  final AngelDeserializer<Data>? deserializer;

  /// The [WebSocketChannel] to listen to, and send data across.
  final WebSocketChannel? socket;

  /// The service path to listen to.
  final String path;

  final StreamController<WebSocketEvent> _onAllEvents =
      StreamController<WebSocketEvent>.broadcast();
  final StreamController<List<Data?>> _onIndexed = StreamController.broadcast();
  final StreamController<Data?> _onRead = StreamController<Data?>.broadcast();
  final StreamController<Data?> _onCreated =
      StreamController<Data?>.broadcast();
  final StreamController<Data?> _onModified =
      StreamController<Data?>.broadcast();
  final StreamController<Data?> _onUpdated =
      StreamController<Data?>.broadcast();
  final StreamController<Data?> _onRemoved =
      StreamController<Data?>.broadcast();

  StreamSubscription<Map<String, WebSocketEvent>>? _subscription;

  /// Fired on all events.
  Stream<WebSocketEvent> get onAllEvents => _onAllEvents.stream;

  /// Fired on `index` events.
  @override
  Stream<List<Data?>> get onIndexed => _onIndexed.stream;

  /// Fired on `read` events.
  @override
  Stream<Data?> get onRead => _onRead.stream;

  /// Fired on `created` events.
  @override
  Stream<Data?> get onCreated => _onCreated.stream;

  /// Fired on `modified` events.
  @override
  Stream<Data?> get onModified => _onModified.stream;

  /// Fired on `updated` events.
  @override
  Stream<Data?> get onUpdated => _onUpdated.stream;

  /// Fired on `removed` events.
  @override
  Stream<Data?> get onRemoved => _onRemoved.stream;

  WebSocketsService(this.socket, this.app, this.path, {this.deserializer}) {
    listen();
  }

  /// Stops listening for the events of the service, and closes its streams.
  @override
  Future close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _onAllEvents.close();
    await _onCreated.close();
    await _onIndexed.close();
    await _onModified.close();
    await _onRead.close();
    await _onRemoved.close();
    await _onUpdated.close();
  }

  /// Serializes an [action] to be sent over a WebSocket.
  dynamic serialize(WebSocketAction action) => json.encode(action);

  /// Deserializes data from a [WebSocketEvent].
  Data? deserialize(dynamic x) {
    return deserializer != null ? deserializer!(x) : x;
  }

  /// Deserializes the contents of an [event].
  WebSocketEvent<Data> transformEvent(WebSocketEvent event) {
    return WebSocketEvent(
      eventName: event.eventName,
      data: deserialize(event.data),
    );
  }

  /// Starts listening for events.
  void listen() {
    _subscription ??= app.onServiceEvent.listen((map) {
      if (map.containsKey(path)) {
        var event = map[path]!;

        _onAllEvents.add(event);

        if (event.eventName == indexedEvent) {
          var d = event.data;
          var transformed = WebSocketEvent(
            eventName: event.eventName,
            data: d is Iterable ? d.map(deserialize).toList() : null,
          );
          if (transformed.data != null) {
            _onIndexed.add(transformed.data!);
          }
          return;
        }

        var transformed = transformEvent(event).data;

        switch (event.eventName) {
          case readEvent:
            _onRead.add(transformed);
            break;
          case createdEvent:
            _onCreated.add(transformed);
            break;
          case modifiedEvent:
            _onModified.add(transformed);
            break;
          case updatedEvent:
            _onUpdated.add(transformed);
            break;
          case removedEvent:
            _onRemoved.add(transformed);
            break;
        }
      }
    });
  }

  /// Sends the given [action] on the [socket].
  void send(WebSocketAction action) {
    app.sendAction(action);
  }

  @override
  Future<List<Data>?> index([Map<String, dynamic>? params]) async {
    app.sendAction(
      WebSocketAction(eventName: '$path::$indexAction', params: params ?? {}),
    );
    return null;
  }

  @override
  Future<Data?> read(id, [Map<String, dynamic>? params]) async {
    app.sendAction(
      WebSocketAction(
        eventName: '$path::$readAction',
        id: id.toString(),
        params: params ?? {},
      ),
    );
    return null;
  }

  @override
  Future<Data?> create(data, [Map<String, dynamic>? params]) async {
    app.sendAction(
      WebSocketAction(
        eventName: '$path::$createAction',
        data: data,
        params: params ?? {},
      ),
    );
    return null;
  }

  @override
  Future<Data?> modify(id, data, [Map<String, dynamic>? params]) async {
    app.sendAction(
      WebSocketAction(
        eventName: '$path::$modifyAction',
        id: id.toString(),
        data: data,
        params: params ?? {},
      ),
    );
    return null;
  }

  @override
  Future<Data?> update(id, data, [Map<String, dynamic>? params]) async {
    app.sendAction(
      WebSocketAction(
        eventName: '$path::$updateAction',
        id: id.toString(),
        data: data,
        params: params ?? {},
      ),
    );
    return null;
  }

  @override
  Future<Data?> remove(id, [Map<String, dynamic>? params]) async {
    app.sendAction(
      WebSocketAction(
        eventName: '$path::$removeAction',
        id: id.toString(),
        params: params ?? {},
      ),
    );
    return null;
  }
}

/// Contains a dynamic Map of [WebSocketEvent] streams.
///
/// Only the events of a name listened to are given.
class WebSocketExtraneousEventHandler {
  final Map<String?, StreamController<WebSocketEvent>> _events = {};

  /// Gives [event] to the stream of [name], if one listens to it.
  void _add(String name, WebSocketEvent event) {
    var controller = _events[name];
    if (controller != null && !controller.isClosed) controller.add(event);
  }

  Stream<WebSocketEvent> operator [](String index) =>
      (_events[index] ??= StreamController<WebSocketEvent>.broadcast()).stream;

  void _close() {
    for (var s in _events.values) {
      s.close();
    }
  }
}
