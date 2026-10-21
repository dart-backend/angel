import 'dart:async';

import 'package:angel3_websocket/angel3_websocket.dart';
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart' as pub_sub;
import 'package:stream_channel/stream_channel.dart';

/// Synchronizes WebSockets using `package:pub_sub`.
///
/// Errors of the [client] (e.g. a refused publish) are added to [stream].
/// Closing [sink], as `AngelWebSocket` does on shutdown, also [close]s the
/// channel, which unsubscribes and closes the [client].
class PubSubSynchronizationChannel extends StreamChannelMixin<WebSocketEvent> {
  /// The event name used to synchronize events on the server.
  static const String eventName = 'angel_sync::event';

  final StreamChannelController<WebSocketEvent> _ctrl =
      StreamChannelController<WebSocketEvent>();

  late final Future<pub_sub.ClientSubscription?> _subscription;

  Future<void>? _closing;

  final pub_sub.Client client;

  PubSubSynchronizationChannel(this.client) {
    _ctrl.local.stream.listen((e) {
      client.publish(eventName, e.toJson()).catchError(_addError);
    }, onDone: close);

    _subscription = client
        .subscribe(eventName)
        .then<pub_sub.ClientSubscription?>((sub) {
          sub.listen((data) {
            // Incoming is a Map
            if (data is Map && _closing == null) {
              _ctrl.local.sink.add(WebSocketEvent.fromJson(data));
            }
          }, onError: _addError);
          return sub;
        })
        .catchError((Object error) {
          _addError(error);
          return null;
        });
  }

  /// Adds [error] to [stream], unless the channel is closing.
  void _addError(Object error, [StackTrace? stackTrace]) {
    if (_closing == null) _ctrl.local.sink.addError(error, stackTrace);
  }

  @override
  Stream<WebSocketEvent> get stream => _ctrl.foreign.stream;

  @override
  StreamSink<WebSocketEvent> get sink => _ctrl.foreign.sink;

  /// Unsubscribes, closes the [client], and ends [stream]. Calling it again
  /// returns the same future.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    try {
      // Waits for a subscription still being made, so that it is ended too.
      await (await _subscription)?.unsubscribe();
    } catch (_) {
      // Closing anyway; the client may already be gone.
    } finally {
      try {
        await client.close();
      } catch (_) {
        // Already closed.
      }
      // Not awaited: it completes only once [stream] is listened to.
      unawaited(_ctrl.local.sink.close());
    }
  }
}
