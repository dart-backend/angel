import 'dart:async';
import 'package:angel_websocket/angel_websocket.dart';
import 'package:pub_sub/pub_sub.dart' as pub_sub;
import 'package:stream_channel/stream_channel.dart';

/// Synchronizes WebSockets using `package:pub_sub`.
class PubSubSynchronizationChannel extends StreamChannelMixin<WebSocketEvent> {
  /// The event name used to synchronize events on the server.
  static const String eventName = 'angel_sync::event';

  final StreamChannelController<WebSocketEvent> _ctrl =
      StreamChannelController<WebSocketEvent>();

  pub_sub.ClientSubscription? _subscription;

  final pub_sub.Client client;

  PubSubSynchronizationChannel(this.client) {
    _ctrl.local.stream.listen((e) {
      client
          .publish(eventName, e.toJson())
          .catchError(_ctrl.local.sink.addError);
    });

    client.subscribe(eventName).then((sub) {
      _subscription = sub
        ..listen((data) {
          // Incoming is a Map
          if (data is Map) {
            var e = WebSocketEvent.fromJson(data);
            _ctrl.local.sink.add(e);
          }
        }, onError: _ctrl.local.sink.addError);
    }).catchError((error) {
      _ctrl.local.sink.addError(error as Object);
    });
  }

  @override
  Stream<WebSocketEvent> get stream => _ctrl.foreign.stream;

  @override
  StreamSink<WebSocketEvent> get sink => _ctrl.foreign.sink;

  Future close() {
    if (_subscription != null) {
      _subscription!.unsubscribe().then((_) => client.close());
    } else {
      client.close();
    }
    return _ctrl.local.sink.close();
  }
}
