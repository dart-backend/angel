import 'dart:async';

import 'package:angel3_websocket/angel3_websocket.dart';
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart' as pub_sub;
import 'package:stream_channel/stream_channel.dart';

/// Synchronizes WebSockets using `package:pub_sub`.
///
/// Errors of the [client] (e.g. a refused publish, or a malformed event) are
/// added to [stream]. Closing [sink], as `AngelWebSocket` does on shutdown,
/// also [close]s the channel, and completes once it is closed.
class PubSubSynchronizationChannel extends StreamChannelMixin<WebSocketEvent> {
  /// The event name used to synchronize events on the server.
  static const String eventName = 'angel_sync::event';

  final StreamChannelController<WebSocketEvent> _ctrl =
      StreamChannelController<WebSocketEvent>();

  late final Future<pub_sub.ClientSubscription?> _subscription;

  Future<void>? _closing;

  late final StreamSink<WebSocketEvent> _sink = _ClosingSink(
    _ctrl.foreign.sink,
    close,
  );

  final pub_sub.Client client;

  /// How long [close] waits for the server, to finish subscribing and to
  /// unsubscribe, before closing the [client] anyway: a server that is gone
  /// never answers.
  final Duration closeTimeout;

  PubSubSynchronizationChannel(
    this.client, {
    this.closeTimeout = const Duration(seconds: 5),
  }) {
    _ctrl.local.stream.listen((e) {
      if (_closing != null) return;
      client.publish(eventName, e.toJson()).catchError(_addError);
    }, onDone: close);

    _subscription = client
        .subscribe(eventName)
        .then<pub_sub.ClientSubscription?>((sub) {
          sub.listen(
            (data) {
              if (data is! Map || _closing != null) return;
              // Sent by another client, e.g. of another version.
              WebSocketEvent event;
              try {
                event = WebSocketEvent.fromJson(data);
              } catch (e, st) {
                _addError(e, st);
                return;
              }
              if (event.eventName?.isNotEmpty != true) {
                _addError(FormatException('A synchronized event has no name.'));
                return;
              }
              _ctrl.local.sink.add(event);
            },
            onError: _addError,
            onDone: () {
              if (_closing != null) return;
              // Nothing is synchronized any more: told, then ended.
              _addError(StateError('The pub_sub subscription ended.'));
              close();
            },
          );
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
  StreamSink<WebSocketEvent> get sink => _sink;

  /// Unsubscribes, closes the [client], and ends [stream]. It waits for the
  /// server at most [closeTimeout] for each step. Calling it again returns the
  /// same future.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    try {
      // Waits for a subscription still being made, so that it is ended too.
      var subscription = await _subscription.timeout(
        closeTimeout,
        onTimeout: () => null,
      );
      await subscription?.unsubscribe().timeout(closeTimeout);
    } catch (_) {
      // Closing anyway; the server may be gone.
    } finally {
      try {
        // Also fails a subscription still waiting for the server.
        await client.close();
      } catch (_) {
        // Already closed.
      }
      // Not awaited: it completes only once [stream] is listened to.
      unawaited(_ctrl.local.sink.close());
    }
  }
}

/// A sink whose [close] also waits for the channel to close.
class _ClosingSink implements StreamSink<WebSocketEvent> {
  final StreamSink<WebSocketEvent> _inner;
  final Future<void> Function() _closeChannel;

  _ClosingSink(this._inner, this._closeChannel);

  @override
  void add(WebSocketEvent event) => _inner.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream<WebSocketEvent> stream) => _inner.addStream(stream);

  @override
  Future close() async {
    await _inner.close();
    await _closeChannel();
  }

  @override
  Future get done => _inner.done;
}
