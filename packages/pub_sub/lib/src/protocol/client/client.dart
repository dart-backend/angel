import 'dart:async';

/// Queries a `pub_sub` server.
abstract class Client {
  /// Publishes an event to the server.
  Future publish(String eventName, value);

  /// Request a [ClientSubscription] to the desired [eventName] from the server.
  Future<ClientSubscription> subscribe(String eventName);

  /// Disposes of this client.
  Future close();
}

/// A client-side implementation of a subscription, which acts as a [Stream], and can be cancelled easily.
abstract class ClientSubscription extends Stream {
  /// Stops listening for new events, and instructs the server to cancel the subscription.
  Future unsubscribe();
}

/// Thrown as the result of an invalid request, or an attempt to perform an action without the correct privileges.
class PubSubException implements Exception {
  /// The error message sent by the server.
  final String message;

  const PubSubException(this.message);

  @override
  String toString() => '`pub_sub` exception: $message';
}
