import 'dart:async';
import 'package:stream_channel/stream_channel.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:uuid/uuid.dart';
import '../../angel3_pub_sub.dart';

/// A [Client] implementation that communicates via JSON RPC 2.0.
class JsonRpc2Client extends Client {
  final Map<String, Completer<Map>> _requests = {};
  final List<_JsonRpc2ClientSubscription> _subscriptions = [];
  final Uuid _uuid = Uuid();

  json_rpc_2.Peer? _peer;

  /// The ID of the client we are authenticating as.
  ///
  /// May be `null`, if and only if we are marked as a trusted source on
  /// the server side.
  String? get clientId => _clientId;
  String? _clientId;

  JsonRpc2Client(String? clientId, StreamChannel<String> channel) {
    _clientId = clientId;
    _peer = json_rpc_2.Peer(channel);

    _peer!.registerMethod('event', (json_rpc_2.Parameters params) {
      String? eventName = params['event_name'].asString;
      var event = params['value'].value;
      for (var s in _subscriptions.where((s) => s.eventName == eventName)) {
        if (!s._stream.isClosed) s._stream.add(event);
      }
    });

    _peer!.registerFallback((json_rpc_2.Parameters params) {
      var c = _requests.remove(params.method);

      if (c == null) {
        throw json_rpc_2.RpcException.methodNotFound(params.method);
      } else {
        var data = params.asMap;

        if (data['status'] is! bool) {
          c.completeError(
              FormatException('The server sent an invalid response.'));
        } else if (!(data['status'] as bool)) {
          c.completeError(PubSubException(data['error_message']?.toString() ??
              'The server sent a failure response, but did not provide an error message.'));
        } else {
          c.complete(data);
        }
      }
    });

    _peer!.listen();
  }

  @override
  Future publish(String eventName, value) {
    var c = Completer<Map>();
    var requestId = _uuid.v4();
    _requests[requestId] = c;
    _peer!.sendNotification('publish', {
      'request_id': requestId,
      'client_id': clientId,
      'event_name': eventName,
      'value': value
    });
    return c.future.then((data) {
      _clientId = data['result']['client_id'] as String?;
    });
  }

  @override
  Future<ClientSubscription> subscribe(String eventName) {
    var c = Completer<Map>();
    var requestId = _uuid.v4();
    _requests[requestId] = c;
    _peer!.sendNotification('subscribe', {
      'request_id': requestId,
      'client_id': clientId,
      'event_name': eventName
    });
    return c.future.then<ClientSubscription>((result) {
      _clientId = result['client_id'] as String?;
      var s = _JsonRpc2ClientSubscription(
          eventName, result['subscription_id'] as String?, this);
      _subscriptions.add(s);
      return s;
    });
  }

  @override
  Future close() {
    if (_peer?.isClosed != true) _peer!.close();

    for (var c in _requests.values) {
      if (!c.isCompleted) {
        c.completeError(StateError(
            'The client was closed before the server responded to this request.'));
      }
    }

    for (var s in _subscriptions) {
      s._close();
    }

    _requests.clear();
    return Future.value();
  }
}

class _JsonRpc2ClientSubscription extends ClientSubscription {
  final StreamController _stream = StreamController();
  final String? eventName, id;
  final JsonRpc2Client client;

  _JsonRpc2ClientSubscription(this.eventName, this.id, this.client);

  void _close() {
    if (!_stream.isClosed) _stream.close();
  }

  @override
  StreamSubscription listen(void Function(dynamic event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _stream.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future unsubscribe() {
    var c = Completer<Map>();
    var requestId = client._uuid.v4();
    client._requests[requestId] = c;
    client._peer!.sendNotification('unsubscribe', {
      'request_id': requestId,
      'client_id': client.clientId,
      'subscription_id': id
    });

    return c.future.then((_) {
      _close();
    });
  }
}
