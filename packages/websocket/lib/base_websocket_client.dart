import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:angel3_client/angel3_client.dart';
import 'package:angel3_client/base_angel_client.dart';
import 'package:http/src/base_client.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'angel3_websocket.dart';
import 'constants.dart';

final RegExp _straySlashes = RegExp(r'(^/)|(/+$)');

/// An [Angel] client that operates across WebSockets.
abstract class BaseWebSocketClient extends BaseAngelClient {
  Duration? _reconnectInterval;
  WebSocketChannel? _socket;
  final Queue<WebSocketAction> _queue = Queue<WebSocketAction>();

  final StreamController _onData = StreamController();
  final StreamController<WebSocketEvent> _onAllEvents =
      StreamController<WebSocketEvent>();
  final StreamController<AngelAuthResult> _onAuthenticated =
      StreamController<AngelAuthResult>();
  final StreamController<AngelHttpException> _onError =
      StreamController<AngelHttpException>();
  final StreamController<Map<String, WebSocketEvent>> _onServiceEvent =
      StreamController<Map<String, WebSocketEvent>>.broadcast();
  final StreamController<WebSocketChannelException>
      _onWebSocketChannelException =
      StreamController<WebSocketChannelException>();

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
  /// if the socket closes.
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

  BaseWebSocketClient(http.BaseClient client, baseUrl,
      {this.reconnectOnClose = true, Duration? reconnectInterval})
      : super(client, baseUrl) {
    _reconnectInterval = reconnectInterval ?? Duration(seconds: 10);
  }

  @override
  Future close() async {
    on._close();
    scheduleMicrotask(() async {
      await _socket!.sink.close(status.goingAway);
      await _onData.close();
      await _onAllEvents.close();
      await _onAuthenticated.close();
      await _onError.close();
      await _onServiceEvent.close();
      await _onWebSocketChannelException.close();
    });
  }

  /// Connects the WebSocket. [timeout] is optional.
  Future<WebSocketChannel?> connect({Duration? timeout}) async {
    if (timeout != null) {
      var c = Completer<WebSocketChannel>();
      late Timer timer;

      timer = Timer(timeout, () {
        if (!c.isCompleted) {
          if (timer.isActive) timer.cancel();
          c.completeError(TimeoutException(
              'WebSocket connection exceeded timeout of ${timeout.inMilliseconds} ms',
              timeout));
        }
      });

      scheduleMicrotask(() {
        getConnectedWebSocket().then((socket) {
          if (!c.isCompleted) {
            if (timer.isActive) timer.cancel();

            while (_queue.isNotEmpty) {
              var action = _queue.removeFirst();
              socket.sink.add(serialize(action));
            }

            c.complete(socket);
          }
        }).catchError((e, StackTrace st) {
          if (!c.isCompleted) {
            if (timer.isActive) {
              timer.cancel();
            }

            // TODO: Re-evaluate this error
            var obj = 'Error';
            c.completeError(obj, st);
          }
        });
      });

      return await c.future.then((socket) {
        _socket = socket;
        listen();

        return _socket;
      });
    } else {
      _socket = await getConnectedWebSocket();
      listen();
      return _socket;
    }
  }

  /// Returns a new [WebSocketChannel], ready to be listened on.
  ///
  /// This should be overriden by child classes, **NOT** [connect].
  Future<WebSocketChannel> getConnectedWebSocket();

  @override
  Service<Id, Data> service<Id, Data>(String path,
      {Type? type, AngelDeserializer<Data>? deserializer}) {
    var uri = path.toString().replaceAll(_straySlashes, '');
    var wsService = WebSocketsService<Id, Data>(socket, this, uri,
        deserializer: deserializer);
    return wsService as Service<Id, Data>;
  }

  /// Starts listening for data.
  void listen() {
    _socket?.stream.listen(
        (data) {
          _onData.add(data);

          if (data is WebSocketChannelException) {
            _onWebSocketChannelException.add(data);
          } else if (data is String) {
            var jsons = json.decode(data);

            if (jsons is Map) {
              var event = WebSocketEvent.fromJson(jsons);

              if (event.eventName?.isNotEmpty == true) {
                _onAllEvents.add(event);
                on._getStream(event.eventName)!.add(event);
              }

              if (event.eventName == errorEvent) {
                var error =
                    AngelHttpException.fromMap((event.data ?? {}) as Map);
                _onError.add(error);
              } else if (event.eventName == authenticatedEvent) {
                var authResult = AngelAuthResult.fromMap(event.data as Map?);
                _onAuthenticated.add(authResult);
              } else if (event.eventName?.isNotEmpty == true) {
                var split = event.eventName!
                    .split('::')
                    .where((str) => str.isNotEmpty)
                    .toList();

                if (split.length >= 2) {
                  var serviceName = split[0], eventName = split[1];
                  _onServiceEvent
                      .add({serviceName: event..eventName = eventName});
                }
              }
            }
          }
        },
        cancelOnError: true,
        onDone: () {
          _socket = null;
          if (reconnectOnClose == true) {
            Timer.periodic(reconnectInterval!, (Timer timer) async {
              WebSocketChannel? result;

              try {
                result = await connect(timeout: reconnectInterval);
              } catch (e) {
                //
              }

              if (result != null) timer.cancel();
            });
          }
        });
  }

  /// Serializes data to JSON.
  dynamic serialize(x) => json.encode(x);

  /// Sends the given [action] on the [socket].
  void sendAction(WebSocketAction action) {
    if (_socket == null) {
      _queue.addLast(action);
    } else {
      socket?.sink.add(serialize(action));
    }
  }

  /// Attempts to authenticate a WebSocket, using a valid JWT.
  void authenticateViaJwt(String? jwt) {
    sendAction(WebSocketAction(
      eventName: authenticateAction,
      params: {
        'query': {'jwt': jwt}
      },
    ));
  }
}

/// A [Service] that asynchronously interacts with the server.
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
      StreamController<WebSocketEvent>();
  final StreamController<List<Data?>> _onIndexed = StreamController();
  final StreamController<Data?> _onRead = StreamController<Data>();
  final StreamController<Data?> _onCreated = StreamController<Data>();
  final StreamController<Data?> _onModified = StreamController<Data>();
  final StreamController<Data?> _onUpdated = StreamController<Data>();
  final StreamController<Data?> _onRemoved = StreamController<Data>();

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

  @override
  Future close() async {
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
  Data? deserialize(x) {
    return deserializer != null ? deserializer!(x) : x as Data?;
  }

  /// Deserializes the contents of an [event].
  WebSocketEvent<Data> transformEvent(WebSocketEvent event) {
    return WebSocketEvent(
        eventName: event.eventName, data: deserialize(event.data));
  }

  /// Starts listening for events.
  void listen() {
    app.onServiceEvent.listen((map) {
      if (map.containsKey(path)) {
        var event = map[path]!;

        _onAllEvents.add(event);

        if (event.eventName == indexedEvent) {
          var d = event.data;
          var transformed = WebSocketEvent(
              eventName: event.eventName,
              data: d is Iterable ? d.map(deserialize).toList() : null);
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
    app.sendAction(WebSocketAction(
        eventName: '$path::$indexAction', params: params ?? {}));
    return null;
  }

  @override
  Future<Data?> read(id, [Map<String, dynamic>? params]) async {
    app.sendAction(WebSocketAction(
        eventName: '$path::$readAction',
        id: id.toString(),
        params: params ?? {}));
    return null;
  }

  @override
  Future<Data?> create(data, [Map<String, dynamic>? params]) async {
    app.sendAction(WebSocketAction(
        eventName: '$path::$createAction', data: data, params: params ?? {}));
    return null;
  }

  @override
  Future<Data?> modify(id, data, [Map<String, dynamic>? params]) async {
    app.sendAction(WebSocketAction(
        eventName: '$path::$modifyAction',
        id: id.toString(),
        data: data,
        params: params ?? {}));
    return null;
  }

  @override
  Future<Data?> update(id, data, [Map<String, dynamic>? params]) async {
    app.sendAction(WebSocketAction(
        eventName: '$path::$updateAction',
        id: id.toString(),
        data: data,
        params: params ?? {}));
    return null;
  }

  @override
  Future<Data?> remove(id, [Map<String, dynamic>? params]) async {
    app.sendAction(WebSocketAction(
        eventName: '$path::$removeAction',
        id: id.toString(),
        params: params ?? {}));
    return null;
  }
}

/// Contains a dynamic Map of [WebSocketEvent] streams.
class WebSocketExtraneousEventHandler {
  final Map<String?, StreamController<WebSocketEvent>> _events = {};

  StreamController<WebSocketEvent>? _getStream(String? index) {
    if (_events[index] == null) {
      _events[index] = StreamController<WebSocketEvent>();
    }

    return _events[index];
  }

  Stream<WebSocketEvent> operator [](String index) {
    if (_events[index] == null) {
      _events[index] = StreamController<WebSocketEvent>();
    }

    return _events[index]!.stream;
  }

  void _close() {
    for (var s in _events.values) {
      s.close();
    }
  }
}
