part of 'server.dart';

/// Represents a WebSocket session, with the original
/// [RequestContext] and [ResponseContext] attached.
class WebSocketContext {
  /// Use this to listen for events.
  WebSocketEventTable on = WebSocketEventTable();

  /// The underlying [StreamChannel].
  final StreamChannel channel;

  /// The original [RequestContext].
  final RequestContext request;

  /// The original [ResponseContext].
  final ResponseContext response;

  final StreamController<WebSocketAction> _onAction =
      StreamController<WebSocketAction>();

  final StreamController<void> _onAuthenticated = StreamController();

  final StreamController<void> _onClose = StreamController<void>();

  final StreamController _onData = StreamController();

  /// Fired on any [WebSocketAction];
  Stream<WebSocketAction> get onAction => _onAction.stream;

  /// Fired when the user authenticates.
  Stream<void> get onAuthenticated => _onAuthenticated.stream;

  /// Fired once the underlying [WebSocket] closes.
  Stream<void> get onClose => _onClose.stream;

  /// Fired when any data is sent through [channel].
  Stream get onData => _onData.stream;

  WebSocketContext(this.channel, this.request, this.response);

  /// Closes the underlying [StreamChannel].
  Future close() async {
    scheduleMicrotask(() async {
      await channel.sink.close();
      await _onAction.close();
      await _onAuthenticated.close();
      await _onData.close();
      //_onClose.add(null);
      await _onClose.close();
    });
  }

  /// Sends an arbitrary [WebSocketEvent];
  void send(String eventName, data) {
    channel.sink.add(
        json.encode(WebSocketEvent(eventName: eventName, data: data).toJson()));
  }

  /// Sends an error event.
  void sendError(AngelHttpException error) => send(errorEvent, error.toJson());
}

class WebSocketEventTable {
  final Map<String, StreamController<Map?>> _handlers = {};

  StreamController<Map?>? _getStreamForEvent(String eventName) {
    if (!_handlers.containsKey(eventName)) {
      _handlers[eventName] = StreamController<Map?>();
    }
    return _handlers[eventName];
  }

  Stream<Map?> operator [](String key) => _getStreamForEvent(key)!.stream;
}
