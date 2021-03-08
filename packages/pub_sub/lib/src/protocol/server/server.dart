import 'dart:async';
import 'dart:math';
import 'adapter.dart';
import 'client.dart';
import 'publish.dart';
import 'subscription.dart';

/// A server that implements the `pub_sub` protocol.
///
/// It can work using multiple [Adapter]s, to simultaneously
/// serve local and remote clients alike.
class Server {
  final List<Adapter> _adapters = [];
  final List<ClientInfo> _clients = [];
  final _rnd = new Random.secure();
  final Map<String, List<Subscription>> _subscriptions = {};
  bool _started = false;
  int _adHocIds = 0;

  /// Initialize a server, optionally with a number of [adapters].
  Server([Iterable<Adapter> adapters = const []]) {
    _adapters.addAll(adapters ?? []);
  }

  /// Adds a new [Adapter] to adapt incoming clients from a new interface.
  void addAdapter(Adapter adapter) {
    if (_started)
      throw new StateError(
          'You cannot add new adapters after the server has started listening.');
    else {
      _adapters.add(adapter);
    }
  }

  /// Registers a new client with the server.
  void registerClient(ClientInfo client) {
    if (_started)
      throw new StateError(
          'You cannot register new clients after the server has started listening.');
    else {
      _clients.add(client);
    }
  }

  /// Disposes of this server, and closes all of its adapters.
  Future close() {
    Future.wait(_adapters.map((a) => a.close()));
    _adapters.clear();
    _clients.clear();
    _subscriptions.clear();
    return new Future.value();
  }

  String _newClientId() {
    // Create an unpredictable-enough ID. The harder it is for an attacker to guess, the better.
    var id =
        'pub_sub::adhoc_client${_rnd.nextDouble()}::${_adHocIds++}:${new DateTime.now().millisecondsSinceEpoch * _rnd.nextDouble()}';

    // This client is coming from a trusted source, and can therefore both publish and subscribe.
    _clients.add(new ClientInfo(id));
    return id;
  }

  void start() {
    if (_adapters.isEmpty)
      throw new StateError(
          'Cannot start a SyncServer that has no adapters attached.');
    else if (_started)
      throw new StateError('A SyncServer may only be started once.');

    _started = true;

    for (var adapter in _adapters) {
      adapter.start();
    }

    for (var adapter in _adapters) {
      // Handle publishes
      adapter.onPublish.listen((rq) {
        ClientInfo client;
        String clientId;

        if (rq.clientId?.isNotEmpty == true ||
            adapter.isTrustedPublishRequest(rq)) {
          clientId =
              rq.clientId?.isNotEmpty == true ? rq.clientId : _newClientId();
          client =
              _clients.firstWhere((c) => c.id == clientId, orElse: () => null);
        }

        if (client == null) {
          rq.reject('Unrecognized client ID "${clientId ?? '<missing>'}".');
        } else if (!client.canPublish) {
          rq.reject('You are not allowed to publish events.');
        } else {
          var listeners = _subscriptions[rq.eventName]
                  ?.where((s) => s.clientId != clientId) ??
              [];

          if (listeners.isEmpty) {
            rq.accept(new PublishResponse(0, clientId));
          } else {
            for (var listener in listeners) {
              listener.dispatch(rq.value);
            }

            rq.accept(new PublishResponse(listeners.length, clientId));
          }
        }
      });

      // Listen for incoming subscriptions
      adapter.onSubscribe.listen((rq) async {
        ClientInfo client;
        String clientId;

        if (rq.clientId?.isNotEmpty == true ||
            adapter.isTrustedSubscriptionRequest(rq)) {
          clientId =
              rq.clientId?.isNotEmpty == true ? rq.clientId : _newClientId();
          client =
              _clients.firstWhere((c) => c.id == clientId, orElse: () => null);
        }

        if (client == null) {
          rq.reject('Unrecognized client ID "${clientId ?? '<missing>'}".');
        } else if (!client.canSubscribe) {
          rq.reject('You are not allowed to subscribe to events.');
        } else {
          var sub = await rq.accept(clientId);
          var list = _subscriptions.putIfAbsent(rq.eventName, () => []);
          list.add(sub);
        }
      });

      // Unregister subscriptions on unsubscribe
      adapter.onUnsubscribe.listen((rq) {
        Subscription toRemove;
        List<Subscription> sourceList;

        for (var list in _subscriptions.values) {
          toRemove = list.firstWhere((s) => s.id == rq.subscriptionId,
              orElse: () => null);
          if (toRemove != null) {
            sourceList = list;
            break;
          }
        }

        if (toRemove == null) {
          rq.reject('The specified subscription does not exist.');
        } else if (toRemove.clientId != rq.clientId) {
          rq.reject('That is not your subscription to cancel.');
        } else {
          sourceList.remove(toRemove);
          rq.accept();
        }
      });
    }
  }
}
