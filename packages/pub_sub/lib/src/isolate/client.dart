import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:uuid/uuid.dart';
import '../../pub_sub.dart';

/// A [Client] implementation that communicates via [SendPort]s and [ReceivePort]s.
class IsolateClient extends Client {
  final Queue<Completer<String>> _onConnect = Queue<Completer<String>>();
  final Map<String, Completer<Map>> _requests = {};
  final List<_IsolateClientSubscription> _subscriptions = [];
  final Uuid _uuid = Uuid();

  String? _id;

  /// The ID of the client we are authenticating as.
  ///
  /// May be `null`, if and only if we are marked as a trusted source on
  /// the server side.
  String? get clientId => _clientId;
  String? _clientId;

  /// A server's [SendPort] that messages should be sent to.
  final SendPort serverSendPort;

  /// A [ReceivePort] that receives messages from the server.
  final ReceivePort receivePort = ReceivePort();

  IsolateClient(String? clientId, this.serverSendPort) {
    _clientId = clientId;
    receivePort.listen((data) {
      if (data is Map && data['request_id'] is String) {
        var requestId = data['request_id'] as String?;
        var c = _requests.remove(requestId);

        if (c != null && !c.isCompleted) {
          if (data['status'] is! bool) {
            c.completeError(
                FormatException('The server sent an invalid response.'));
          } else if (!(data['status'] as bool)) {
            c.completeError(PubSubException(data['error_message']?.toString() ??
                'The server sent a failure response, but did not provide an error message.'));
          } else if (data['result'] is! Map) {
            c.completeError(FormatException(
                'The server sent a success response, but did not include a result.'));
          } else {
            c.complete(data['result'] as Map?);
          }
        }
      } else if (data is Map && data['id'] is String && _id == null) {
        _id = data['id'] as String?;

        for (var c in _onConnect) {
          if (!c.isCompleted) c.complete(_id);
        }

        _onConnect.clear();
      } else if (data is List && data.length == 2 && data[0] is String) {
        var eventName = data[0] as String;
        var event = data[1];
        for (var s in _subscriptions.where((s) => s.eventName == eventName)) {
          if (!s._stream.isClosed) s._stream.add(event);
        }
      }
    });
    serverSendPort.send(receivePort.sendPort);
  }

  Future<T> _whenConnected<T>(FutureOr<T> Function() callback) {
    if (_id != null) {
      return Future<T>.sync(callback);
    } else {
      var c = Completer<String>();
      _onConnect.add(c);
      return c.future.then<T>((_) => callback());
    }
  }

  @override
  Future publish(String eventName, value) {
    return _whenConnected(() {
      var c = Completer<Map>();
      var requestId = _uuid.v4();
      _requests[requestId] = c;
      serverSendPort.send({
        'id': _id,
        'request_id': requestId,
        'method': 'publish',
        'params': {
          'client_id': clientId,
          'event_name': eventName,
          'value': value
        }
      });
      return c.future.then((result) {
        _clientId = result['client_id'] as String?;
      });
    });
  }

  @override
  Future<ClientSubscription> subscribe(String eventName) {
    return _whenConnected<ClientSubscription>(() {
      var c = Completer<Map>();
      var requestId = _uuid.v4();
      _requests[requestId] = c;
      serverSendPort.send({
        'id': _id,
        'request_id': requestId,
        'method': 'subscribe',
        'params': {'client_id': clientId, 'event_name': eventName}
      });
      return c.future.then<ClientSubscription>((result) {
        _clientId = result['client_id'] as String?;
        var s = _IsolateClientSubscription(
            eventName, result['subscription_id'] as String?, this);
        _subscriptions.add(s);
        return s;
      });
    });
  }

  @override
  Future close() {
    receivePort.close();

    for (var c in _onConnect) {
      if (!c.isCompleted) {
        c.completeError(StateError(
            'The client was closed before the server ever accepted the connection.'));
      }
    }

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

class _IsolateClientSubscription extends ClientSubscription {
  final StreamController _stream = StreamController();
  final String? eventName, id;
  final IsolateClient client;

  _IsolateClientSubscription(this.eventName, this.id, this.client);

  void _close() {
    if (!_stream.isClosed) _stream.close();
  }

  @override
  StreamSubscription listen(void onData(event)?,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _stream.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future unsubscribe() {
    return client._whenConnected(() {
      var c = Completer<Map>();
      var requestId = client._uuid.v4();
      client._requests[requestId] = c;
      client.serverSendPort.send({
        'id': client._id,
        'request_id': requestId,
        'method': 'unsubscribe',
        'params': {'client_id': client.clientId, 'subscription_id': id}
      });

      return c.future.then((_) {
        _close();
      });
    });
  }
}
