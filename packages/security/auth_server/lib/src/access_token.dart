import 'server.dart';

/// An access token that the server issued, as
/// [AuthorizationServer.findAccessToken]
/// finds it, of a request to a resource that
/// [AuthorizationServer.requireToken]
/// protects (RFC 6750).
class AccessToken<Client, User> {
  /// The client that the token was issued to.
  final Client? client;

  /// The user, the resource owner, who granted it; `null` for a token of a
  /// client credentials grant, which is of the client alone.
  final User? user;

  /// The scopes that the token grants.
  final Iterable<String> scopes;

  /// When the token expires, if it does; it is refused from then on.
  final DateTime? expiresAt;

  /// When the token was issued, if known, which introspection gives.
  final DateTime? issuedAt;

  const AccessToken({
    this.client,
    this.user,
    this.scopes = const [],
    this.expiresAt,
    this.issuedAt,
  });

  /// Whether the token has expired, as of [now].
  bool isExpiredAt(DateTime now) =>
      expiresAt != null && !expiresAt!.isAfter(now);
}
