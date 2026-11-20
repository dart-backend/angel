// ignore_for_file: todo
import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_oauth2_server/angel3_oauth2_server.dart';

void main() async {
  var app = Angel();
  var oauth2 = _ExampleAuthorizationServer();

  app.group('/auth', (router) {
    router
      ..get('/authorize', oauth2.authorizationEndpoint)
      ..post('/authorize', oauth2.authorizationEndpoint)
      ..post('/token', oauth2.tokenEndpoint);
  });

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
