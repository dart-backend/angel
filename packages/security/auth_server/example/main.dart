// ignore_for_file: todo
import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_auth_server/angel3_auth_server.dart';

void main() async {
  var app = Angel();
  var oauth2 = _ExampleAuthorizationServer();

  app.group('/auth', (router) {
    router
      ..get('/authorize', oauth2.authorizationEndpoint)
      ..post('/authorize', oauth2.authorizationEndpoint)
      ..post('/token', oauth2.tokenEndpoint)
      ..post('/revoke', oauth2.revocationEndpoint)
      ..post('/introspect', oauth2.introspectionEndpoint);
  });

  // The metadata of the server, from which clients find its endpoints.
  var issuer = Uri.parse('https://example.com');
  var metadata = ServerMetadata(
    issuer: issuer,
    authorizationEndpoint: issuer.resolve('/auth/authorize'),
    tokenEndpoint: issuer.resolve('/auth/token'),
    revocationEndpoint: issuer.resolve('/auth/revoke'),
    introspectionEndpoint: issuer.resolve('/auth/introspect'),
    registrationEndpoint: issuer.resolve('/auth/register'),
    grantTypes: ['authorization_code', 'refresh_token'],
  );
  app.get(metadata.wellKnownPath, oauth2.metadataEndpoint(metadata));
  // Clients that register themselves, of the metadata that they may.
  app.post('/auth/register', oauth2.registrationEndpoint(metadata));
  // Which they may then read, update and delete.
  var manage = oauth2.registrationManagementEndpoint(metadata);
  app
    ..get('/auth/register/:client_id', manage)
    ..put('/auth/register/:client_id', manage)
    ..delete('/auth/register/:client_id', manage);

  // Assume that all other requests must be authenticated, by an access
  // token of the `Authorization: Bearer` header, which `findAccessToken`
  // looks up.
  app.fallback(oauth2.requireToken());
  app.get('/me', (req, res) {
    var token = req.container!.make<AccessToken<ThirdPartyApp, User>>();
    return {'scopes': token.scopes.toList()};
  });
}

class ThirdPartyApp {}

class User {}

/// A [ThirdPartyApp] can act on behalf of a [User].
class _ExampleAuthorizationServer
    extends AuthorizationServer<ThirdPartyApp, User> {
  @override
  FutureOr<bool> mayRegisterClient(
    String? initialAccessToken,
    RequestContext req,
  ) {
    // TODO: Accept the initial access tokens that you give developers, or
    // return true for open registration.
    return false;
  }

  @override
  FutureOr<void> registerClient(
    ClientRegistration registration,
    RequestContext req,
  ) {
    // TODO: Store the client, with its secret hashed, so that findClient and
    // verifyClient find it.
    throw UnimplementedError();
  }

  @override
  FutureOr<bool> mayIntrospect(ThirdPartyApp caller, RequestContext req) {
    // TODO: Return true of the clients that are your resource servers.
    return false;
  }

  @override
  bool get managesClientRegistrations => true;

  @override
  FutureOr<ClientRegistration?> findRegistration(
    String clientId,
    String registrationAccessToken,
    RequestContext req,
  ) {
    // TODO: Find the registration of the client, if the token, compared with
    // its stored hash in constant time, is its; or return null.
    throw UnimplementedError();
  }

  @override
  FutureOr<void> updateClient(
    ClientRegistration current,
    ClientRegistration updated,
    RequestContext req,
  ) {
    // TODO: Store the updated registration, and its secret and registration
    // access token, hashed, only if they are new.
    throw UnimplementedError();
  }

  @override
  FutureOr<void> deleteClient(
    ClientRegistration registration,
    RequestContext req,
  ) {
    // TODO: Delete the client, and revoke its tokens.
    throw UnimplementedError();
  }

  @override
  FutureOr<void> revokeToken(
    ThirdPartyApp client,
    String token,
    String? tokenTypeHint,
    RequestContext req,
    ResponseContext res,
  ) {
    // TODO: Revoke the token, if it was issued to the client, and the tokens
    // of its grant; do nothing for an unknown one.
    throw UnimplementedError();
  }

  @override
  FutureOr<AccessToken<ThirdPartyApp, User>?> findAccessToken(
    String token,
    RequestContext req,
  ) {
    // TODO: Look up the token that a grant method issued, with its client,
    // user, scopes and expiry, or return null if there is none.
    throw UnimplementedError();
  }

  @override
  FutureOr<ThirdPartyApp> findClient(String? clientId) {
    // TODO: Add your code to find the app associated with a client ID.
    throw UnimplementedError();
  }

  @override
  FutureOr<bool> verifyClient(ThirdPartyApp client, String? clientSecret) {
    // TODO: Add your code to verify a client secret, if given one.
    throw UnimplementedError();
  }

  @override
  FutureOr requestAuthorizationCode(
    ThirdPartyApp client,
    String? redirectUri,
    Iterable<String> scopes,
    String state,
    RequestContext req,
    ResponseContext res,
    bool implicit,
  ) {
    // TODO: In many cases, here you will render a view displaying to the user which scopes are being requested.
    throw UnimplementedError();
  }

  @override
  FutureOr<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
    ThirdPartyApp? client,
    String? authCode,
    String? redirectUri,
    RequestContext req,
    ResponseContext res,
  ) {
    // TODO: Here, you'll convert the auth code into a full-fledged token.
    // You might have the auth code stored in a database somewhere.
    throw UnimplementedError();
  }
}
