/// Represents information about a client that will be accessing
/// this `angel_sync` server.
class ClientInfo {
  /// A unique identifier for this client.
  final String id;

  /// If `true` (default), then the client is allowed to publish events.
  final bool canPublish;

  /// If `true` (default), then the client can subscribe to events.
  final bool canSubscribe;

  const ClientInfo(this.id, {this.canPublish = true, this.canSubscribe = true});
}
