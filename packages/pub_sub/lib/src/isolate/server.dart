import 'dart:async';
import 'dart:isolate';
import 'package:uuid/uuid.dart';
import '../../pub_sub.dart';

/// A [Adapter] implementation that communicates via [SendPort]s and [ReceivePort]s.
class IsolateAdapter extends Adapter {
  final Map<String, SendPort> _clients = {};
  final StreamController<PublishRequest> _onPublish =
      new StreamController<PublishRequest>();
  final StreamController<SubscriptionRequest> _onSubscribe =
      new StreamController<SubscriptionRequest>();
  final StreamController<UnsubscriptionRequest> _onUnsubscribe =
      new StreamController<UnsubscriptionRequest>();
  final Uuid _uuid = new Uuid();

  /// A [ReceivePort] on which to listen for incoming data.
  final ReceivePort receivePort = new ReceivePort();

  @override
  Stream<PublishRequest> get onPublish => _onPublish.stream;

  @override
  Stream<SubscriptionRequest> get onSubscribe => _onSubscribe.stream;

  @override
  Stream<UnsubscriptionRequest> get onUnsubscribe => _onUnsubscribe.stream;

  @override
  Future close() {
    receivePort.close();
    _clients.clear();
    _onPublish.close();
    _onSubscribe.close();
    _onUnsubscribe.close();
    return new Future.value();
  }

  @override
  void start() {
    receivePort.listen((data) {
      if (data is SendPort) {
        var id = _uuid.v4();
        _clients[id] = data;
        data.send({'status': true, 'id': id});
      } else if (data is Map &&
          data['id'] is String &&
          data['request_id'] is String &&
          data['method'] is String &&
          data['params'] is Map) {
        var id = data['id'] as String,
            requestId = data['request_id'] as String,
            method = data['method'] as String;
        var params = data['params'] as Map;
        var sp = _clients[id];

        if (sp == null) {
          // There's nobody to respond to, so don't send anything to anyone. Oops.
        } else if (method == 'publish') {
          if (_isValidClientId(params['client_id']) &&
              params['event_name'] is String &&
              params.containsKey('value')) {
            var clientId = params['client_id'] as String,
                eventName = params['event_name'] as String;
            var value = params['value'];
            var rq = new _IsolatePublishRequestImpl(
                requestId, clientId, eventName, value, sp);
            _onPublish.add(rq);
          } else {
            sp.send({
              'status': false,
              'request_id': requestId,
              'error_message': 'Expected client_id, event_name, and value.'
            });
          }
        } else if (method == 'subscribe') {
          if (_isValidClientId(params['client_id']) &&
              params['event_name'] is String) {
            var clientId = params['client_id'] as String,
                eventName = params['event_name'] as String;
            var rq = new _IsolateSubscriptionRequestImpl(
                clientId, eventName, sp, requestId, _uuid);
            _onSubscribe.add(rq);
          } else {
            sp.send({
              'status': false,
              'request_id': requestId,
              'error_message': 'Expected client_id, and event_name.'
            });
          }
        } else if (method == 'unsubscribe') {
          if (_isValidClientId(params['client_id']) &&
              params['subscription_id'] is String) {
            var clientId = params['client_id'] as String,
                subscriptionId = params['subscription_id'] as String;
            var rq = new _IsolateUnsubscriptionRequestImpl(
                clientId, subscriptionId, sp, requestId);
            _onUnsubscribe.add(rq);
          } else {
            sp.send({
              'status': false,
              'request_id': requestId,
              'error_message': 'Expected client_id, and subscription_id.'
            });
          }
        } else {
          sp.send({
            'status': false,
            'request_id': requestId,
            'error_message':
                'Unrecognized method "$method". Or, you omitted id, request_id, method, or params.'
          });
        }
      }
    });
  }

  bool _isValidClientId(id) => id == null || id is String;

  @override
  bool isTrustedPublishRequest(PublishRequest request) {
    // Isolate clients are considered trusted, because they are
    // running in the same process as the central server.
    return true;
  }

  @override
  bool isTrustedSubscriptionRequest(SubscriptionRequest request) {
    return true;
  }
}

class _IsolatePublishRequestImpl extends PublishRequest {
  @override
  final String clientId;

  @override
  final String eventName;

  @override
  final value;

  final SendPort sendPort;

  final String requestId;

  _IsolatePublishRequestImpl(
      this.requestId, this.clientId, this.eventName, this.value, this.sendPort);

  @override
  void accept(PublishResponse response) {
    sendPort.send({
      'status': true,
      'request_id': requestId,
      'result': {
        'listeners': response.listeners,
        'client_id': response.clientId
      }
    });
  }

  @override
  void reject(String errorMessage) {
    sendPort.send({
      'status': false,
      'request_id': requestId,
      'error_message': errorMessage
    });
  }
}

class _IsolateSubscriptionRequestImpl extends SubscriptionRequest {
  @override
  final String clientId;

  @override
  final String eventName;

  final SendPort sendPort;

  final String requestId;

  final Uuid _uuid;

  _IsolateSubscriptionRequestImpl(
      this.clientId, this.eventName, this.sendPort, this.requestId, this._uuid);

  @override
  void reject(String errorMessage) {
    sendPort.send({
      'status': false,
      'request_id': requestId,
      'error_message': errorMessage
    });
  }

  @override
  FutureOr<Subscription> accept(String clientId) {
    var id = _uuid.v4();
    sendPort.send({
      'status': true,
      'request_id': requestId,
      'result': {'subscription_id': id, 'client_id': clientId}
    });
    return new _IsolateSubscriptionImpl(clientId, id, eventName, sendPort);
  }
}

class _IsolateSubscriptionImpl extends Subscription {
  @override
  final String clientId, id;

  final String eventName;

  final SendPort sendPort;

  _IsolateSubscriptionImpl(
      this.clientId, this.id, this.eventName, this.sendPort);

  @override
  void dispatch(event) {
    sendPort.send([eventName, event]);
  }
}

class _IsolateUnsubscriptionRequestImpl extends UnsubscriptionRequest {
  @override
  final String clientId;

  @override
  final String subscriptionId;

  final SendPort sendPort;

  final String requestId;

  _IsolateUnsubscriptionRequestImpl(
      this.clientId, this.subscriptionId, this.sendPort, this.requestId);

  @override
  void reject(String errorMessage) {
    sendPort.send({
      'status': false,
      'request_id': requestId,
      'error_message': errorMessage
    });
  }

  @override
  void accept() {
    sendPort.send({'status': true, 'request_id': requestId, 'result': {}});
  }
}
