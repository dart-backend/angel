part of 'server.dart';

/// Represents a WebSocket session, with the original
/// [RequestContext] and [ResponseContext] attached.
///
/// Its streams are broadcast streams: an event is given to those listening
/// when it comes, and is not kept for those who listen later.
class WebSocketContext {
  /// Use this to listen for events.
  WebSocketEventTable on = WebSocketEventTable();

  /// The underlying [StreamChannel].
  final StreamChannel channel;

  /// The original [RequestContext].
  final RequestContext request;

  /// The original [ResponseContext].
  final ResponseContext response;

  /// Serializes the events [send] sends, as `json.encode` by default.
  final WebSocketResponseSerializer? serializer;

  final StreamController<WebSocketAction> _onAction =
      StreamController<WebSocketAction>.broadcast();

  final StreamController<void> _onAuthenticated =
      StreamController<void>.broadcast();

  final StreamController<void> _onClose = StreamController<void>.broadcast();

  final StreamController _onData = StreamController.broadcast();

  /// Whether the socket has closed.
  bool _closed = false;

  /// Fired on any [WebSocketAction];
  Stream<WebSocketAction> get onAction => _onAction.stream;

  /// Fired when the user authenticates.
  Stream<void> get onAuthenticated => _onAuthenticated.stream;

  /// Fired once the underlying [WebSocket] closes.
  Stream<void> get onClose => _onClose.stream;

  /// Fired when any data is sent through [channel].
  Stream get onData => _onData.stream;

  WebSocketContext(
    this.channel,
    this.request,
    this.response, {
    this.serializer,
  });

  /// Closes the underlying [StreamChannel].
  Future close() async {
    await channel.sink.close();
    _markClosed();
  }

  /// Fires [onClose], once, and closes the streams of this socket.
  void _markClosed() {
    if (_closed) return;
    _closed = true;
    _onClose.add(null);
    _onAction.close();
    _onAuthenticated.close();
    _onData.close();
    _onClose.close();
    on._close();
  }

  /// Sends an arbitrary [WebSocketEvent];
  void send(String eventName, data) {
    if (_closed) return;
    channel.sink.add(
      (serializer ?? json.encode)(
        WebSocketEvent(eventName: eventName, data: data).toJson(),
      ),
    );
  }

  /// Sends an error event.
  void sendError(AngelHttpException error) => send(errorEvent, error.toJson());
}

/// The data of the actions of a socket, by event name.
///
/// Only the events of a name listened to are given, and only of data that is
/// a map, or `null`.
class WebSocketEventTable {
  final Map<String, StreamController<Map?>> _handlers = {};

  StreamController<Map?>? _getStreamForEvent(String eventName) =>
      _handlers[eventName] ??= StreamController<Map?>.broadcast();

  /// Whether the stream of [eventName] has a listener.
  bool _hasListener(String eventName) =>
      _handlers[eventName]?.hasListener ?? false;

  /// Gives [data] to the stream of [eventName], if one listens to it.
  void _add(String eventName, Object? data) {
    var controller = _handlers[eventName];
    if (controller != null && !controller.isClosed && data is Map?) {
      controller.add(data);
    }
  }

  void _close() {
    for (var controller in _handlers.values) {
      controller.close();
    }
  }

  /// The data of the actions named [key] that are JSON objects (or `null`);
  /// others are only given to [WebSocketContext.onAction].
  Stream<Map?> operator [](String key) => _getStreamForEvent(key)!.stream;
}
