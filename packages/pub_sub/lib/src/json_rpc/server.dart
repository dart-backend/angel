import 'dart:async';
import 'package:stream_channel/stream_channel.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:uuid/uuid.dart';
import '../../angel3_pub_sub.dart';

/// A [Adapter] implementation that communicates via JSON RPC 2.0.
class JsonRpc2Adapter extends Adapter {
  final StreamController<PublishRequest> _onPublish =
      StreamController<PublishRequest>();
  final StreamController<SubscriptionRequest> _onSubscribe =
      StreamController<SubscriptionRequest>();
  final StreamController<UnsubscriptionRequest> _onUnsubscribe =
      StreamController<UnsubscriptionRequest>();

  final List<json_rpc_2.Peer> _peers = [];
  final Uuid _uuid = Uuid();

  json_rpc_2.Peer? _peer;

  /// A [Stream] of incoming clients, who can both send and receive string data.
  final Stream<StreamChannel<String>> clientStream;

  /// If `true`, clients can connect through this endpoint, *without* providing a client ID.
  ///
  /// This can be a security vulnerability if you don't know what you're doing.
  /// If you *must* use this over the Internet, use an IP whitelist.
  final bool isTrusted;

  JsonRpc2Adapter(this.clientStream, {this.isTrusted = false});

  @override
  Stream<PublishRequest> get onPublish => _onPublish.stream;

  @override
  Stream<SubscriptionRequest> get onSubscribe => _onSubscribe.stream;

  @override
  Stream<UnsubscriptionRequest> get onUnsubscribe => _onUnsubscribe.stream;

  @override
  Future close() {
    if (_peer?.isClosed != true) _peer?.close();

    Future.wait(_peers.where((s) => !s.isClosed).map((s) => s.close()))
        .then((_) => _peers.clear());
    return Future.value();
  }

  String? _getClientId(json_rpc_2.Parameters params) {
    try {
      return params['client_id'].asString;
    } catch (_) {
      return null;
    }
  }

  @override
  void start() {
    clientStream.listen((client) {
      var peer = _peer = json_rpc_2.Peer(client);

      peer.registerMethod('publish', (json_rpc_2.Parameters params) async {
        var requestId = params['request_id'].asString;
        var clientId = _getClientId(params);
        var eventName = params['event_name'].asString;
        var value = params['value'].value;
        var rq = _JsonRpc2PublishRequestImpl(
            requestId, clientId, eventName, value, peer);
        _onPublish.add(rq);
      });

      peer.registerMethod('subscribe', (json_rpc_2.Parameters params) async {
        var requestId = params['request_id'].asString;
        var clientId = _getClientId(params);
        var eventName = params['event_name'].asString;
        var rq = _JsonRpc2SubscriptionRequestImpl(
            clientId, eventName, requestId, peer, _uuid);
        _onSubscribe.add(rq);
      });

      peer.registerMethod('unsubscribe', (json_rpc_2.Parameters params) async {
        var requestId = params['request_id'].asString;
        var clientId = _getClientId(params);
        var subscriptionId = params['subscription_id'].asString;
        var rq = _JsonRpc2UnsubscriptionRequestImpl(
            clientId, subscriptionId, peer, requestId);
        _onUnsubscribe.add(rq);
      });

      peer.listen();
    });
  }

  @override
  bool isTrustedPublishRequest(PublishRequest request) {
    return isTrusted;
  }

  @override
  bool isTrustedSubscriptionRequest(SubscriptionRequest request) {
    return isTrusted;
  }
}

class _JsonRpc2PublishRequestImpl extends PublishRequest {
  final String requestId;

  @override
  final String? clientId, eventName;

  @override
  final value;

  final json_rpc_2.Peer peer;

  _JsonRpc2PublishRequestImpl(
      this.requestId, this.clientId, this.eventName, this.value, this.peer);

  @override
  void accept(PublishResponse response) {
    peer.sendNotification(requestId, {
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
    peer.sendNotification(requestId, {
      'status': false,
      'request_id': requestId,
      'error_message': errorMessage
    });
  }
}

class _JsonRpc2SubscriptionRequestImpl extends SubscriptionRequest {
  @override
  final String? clientId, eventName;

  final String requestId;

  final json_rpc_2.Peer peer;

  final Uuid _uuid;

  _JsonRpc2SubscriptionRequestImpl(
      this.clientId, this.eventName, this.requestId, this.peer, this._uuid);

  @override
  FutureOr<Subscription> accept(String? clientId) {
    var id = _uuid.v4();
    peer.sendNotification(requestId, {
      'status': true,
      'request_id': requestId,
      'subscription_id': id,
      'client_id': clientId
    });
    return _JsonRpc2SubscriptionImpl(clientId, id, eventName, peer);
  }

  @override
  void reject(String errorMessage) {
    peer.sendNotification(requestId, {
      'status': false,
      'request_id': requestId,
      'error_message': errorMessage
    });
  }
}

class _JsonRpc2SubscriptionImpl extends Subscription {
  @override
  final String? clientId, id;

  final String? eventName;

  final json_rpc_2.Peer peer;

  _JsonRpc2SubscriptionImpl(this.clientId, this.id, this.eventName, this.peer);

  @override
  void dispatch(event) {
    peer.sendNotification('event', {'event_name': eventName, 'value': event});
  }
}

class _JsonRpc2UnsubscriptionRequestImpl extends UnsubscriptionRequest {
  @override
  final String? clientId;

  @override
  final String subscriptionId;

  final json_rpc_2.Peer peer;

  final String requestId;

  _JsonRpc2UnsubscriptionRequestImpl(
      this.clientId, this.subscriptionId, this.peer, this.requestId);

  @override
  void accept() {
    peer.sendNotification(requestId, {'status': true, 'result': {}});
  }

  @override
  void reject(String errorMessage) {
    peer.sendNotification(requestId, {
      'status': false,
      'request_id': requestId,
      'error_message': errorMessage
    });
  }
}
