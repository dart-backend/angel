# Angel3 OAuth2 Server

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_oauth2_server?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/security/oauth2_server/LICENSE)

A class containing handlers that can be used within [Angel3](https://angel3-framework.web.app/) to build a spec-compliant OAuth 2.0 server, including PKCE support.

- [Angel3 OAuth2 Server](#angel3-oauth2-server)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Redirect URIs](#redirect-uris)
  - [Other Grants](#other-grants)
  - [Device Authorization](#device-authorization)
  - [PKCE](#pkce)
  - [Protecting Resources](#protecting-resources)
  - [Revoking Tokens](#revoking-tokens)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_framework: ^10.0.0
  angel3_oauth2_server: ^10.0.0
```

## Usage

Your server needs to have definitions of at least two types:

- One model that represents a third-party application (client) trying to access a user's profile.
- One that represents a user logged into the application.

Define a server class as such:

```dart
import 'package:angel3_oauth2_server/angel3_oauth2_server.dart' as oauth2;

class MyServer extends oauth2.AuthorizationServer<Client, User> {}
```

Then, implement the `findClient` and `verifyClient` to ensure that the server class can not only identify a client application via a `client_id`, but that it can also verify its identity via a `client_secret`.

At the token endpoint, a client authenticates with an `Authorization: Basic` header, or, without one (a header of another scheme is ignored), with `client_id` and `client_secret` in the form of the request (RFC 6749 §2.3.1). A public client, such as a mobile app with PKCE, gives its `client_id` alone, and `verifyClient` is given a `null` secret, as it is for an empty one: return `true` for it only for clients that may have none. A client that is not authenticated gets `invalid_client`, a 401. A `client_id` or `client_secret` given in the form with the header must be the header's. A client without a secret may use the authorization code, password and refresh token grants, but not the client credentials grant, which is for confidential clients: it gets `unauthorized_client`.

```dart
class _Server extends AuthorizationServer<PseudoApplication, Map> {
  final Uuid _uuid = Uuid();

  @override
  FutureOr<PseudoApplication>? findClient(String? clientId) {
    return clientId == pseudoApplication.id ? pseudoApplication : null;
  }

  @override
  Future<bool> verifyClient(
      PseudoApplication client, String? clientSecret) async {
    // A public client, stored without a secret, gives none: `null`.
    if (client.secret.isEmpty) return clientSecret == null;
    return client.secret == clientSecret;
  }
}
```

Next, write some logic to be executed whenever a user visits the authorization endpoint. In many cases, you will want to show a dialog. `implicit` is `true` when the client asks for an implicit grant:

```dart
@override
Future<void> requestAuthorizationCode(
  PseudoApplication client,
  String? redirectUri,
  Iterable<String> scopes,
  String state,
  RequestContext req,
  ResponseContext res,
  bool implicit) async {
  await res.render('dialog');
}
```

Once the user grants access, issue a code, store it with the client, the `redirect_uri` and the scopes, and redirect the user with `completeAuthorizationCode`, which adds the `code` and `state` to the redirect URI (RFC 6749 §4.1.2); for an implicit grant, `completeImplicitGrant` does the same with a token:

```dart
await res.redirect(
  completeAuthorizationCode(code, Uri.parse(redirectUri!), state: state),
);
```

Now, write logic that exchanges an authorization code for an access token, and optionally, a refresh token. `redirectUri` is `null` if the token request gives none: if the authorization request of the code gave one, the token request must give the same (RFC 6749 §4.1.3), so check it against the one stored with the code.

```dart
@override
Future<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
  PseudoApplication? client,
  String? authCode,
  String? redirectUri,
  RequestContext req,
  ResponseContext res) async {
    return AuthorizationTokenResponse('foo', refreshToken: 'bar');
}
```

Now, set up some routes to point the server.

```dart
void pseudoCode() {
  app.group('/oauth2', (router) {
    router
      ..get('/authorize', server.authorizationEndpoint)
      ..post('/authorize', server.authorizationEndpoint)
      ..post('/token', server.tokenEndpoint);
  });
}
```

The `authorizationEndpoint` reads its parameters from the query, or from the form of a POST (RFC 6749 §3.1).

The `authorizationEndpoint` and `tokenEndpoint` handle all OAuth2 grant types. The responses of the `tokenEndpoint` have `Cache-Control: no-store` and `Pragma: no-cache`, and the `scope` of a token is a string, of space-separated scopes (RFC 6749 §5.1).

## Redirect URIs

By default, the server does not know the redirect URIs of its clients: an authorization request must give a `redirect_uri`, which `requestAuthorizationCode` is to check, and its errors are thrown, not redirected, as the URI may be an attacker's.

Implement `registeredRedirectUri` to check it instead. Return the registered URI that the request gives, or, if it gives none, the client's registered one; throw an `AuthorizationException` if it is not registered, which is not redirected. Once it returns one, the request may leave out its `redirect_uri`, and its errors, such as an `access_denied` thrown by `requestAuthorizationCode` or an unsupported `response_type`, are redirected to the URI, and any other error as `server_error`, which is logged, with their `error`, `error_description` and the request's `state`: in the query, or, for an implicit grant, in the fragment (RFC 6749 §4.1.2.1, §4.2.2.1).

```dart
@override
Uri? registeredRedirectUri(PseudoApplication client, String? redirectUri) {
  var registered = Uri.parse(client.redirectUri);
  if (redirectUri == null || redirectUri == client.redirectUri) {
    return registered;
  }
  throw AuthorizationException(
    ErrorResponse(
      ErrorResponse.invalidRequest,
      'The "redirect_uri" is not registered.',
      '',
    ),
  );
}
```

## Other Grants

By default, all OAuth2 grant methods will throw a `400 Bad Request` error: an `unsupported_grant_type` OAuth2 error at the token endpoint, or `unsupported_response_type` for an authorization request. To support any specific grant type, all you need to do is implement the method. The following are available, not including authorization code grant support (mentioned above):

- `refreshAuthorizationToken`
- `resourceOwnerPasswordCredentialsGrant`
- `clientCredentialsGrant`, given the `scope` of the request
- `requestDeviceCode` and `exchangeDeviceCodeForToken`, of the [device authorization grant](#device-authorization)

An implicit grant is requested through `requestAuthorizationCode`, with `implicit` set to `true`.

Read the [OAuth2 specification](https://tools.ietf.org/html/rfc6749) for in-depth information on each grant type.

## Device Authorization

A device without a browser, such as a TV or a command line tool, asks the `deviceAuthorizationEndpoint` for a device code (RFC 8628). Route a POST to it:

```dart
router.post('/device', server.deviceAuthorizationEndpoint);
```

It authenticates the client as the `tokenEndpoint` does: a public client, as a device usually is, gives its `client_id` alone, and `verifyClient` is given a `null` secret. It gives the `DeviceCodeResponse` of `requestDeviceCode`, of the `scope` of the request: show the user its `userCode`, and the `verificationUri`, on which they authorize the device on another one. The device then polls the `tokenEndpoint` with `grant_type=urn:ietf:params:oauth:grant-type:device_code` and its `device_code`, which `exchangeDeviceCodeForToken` answers with a token, once the user has authorized it, or with `authorization_pending`, `slow_down`, `access_denied` or `expired_token` (`ErrorResponse.authorizationPending`, and so on). Without `requestDeviceCode`, it is `unsupported_grant_type`.

A device code request to the `tokenEndpoint`, without a `grant_type`, as earlier versions required, still works, but is deprecated, and logged once: it will be removed in a later major version. Without `requestDeviceCode`, it is `invalid_request`, as the `grant_type` is missing.

## PKCE

An authorization code grant must use [PKCE](https://tools.ietf.org/html/rfc7636) with the `S256` method, by default, as OAuth 2.1 and RFC 9700 have it, so that an intercepted authorization code cannot be redeemed:

- The authorization request must give a `code_challenge`, of 43 to 128 characters, and `code_challenge_method=S256`, or it is `invalid_request`: one without a method is `plain`, which is refused.
- The token request must give a `code_verifier`, of 43 to 128 characters, or it is `invalid_request`.

`package:oauth2` and other standard clients do so. A public client, such as a mobile app, which has no secret, sends its `client_id` in the form of its token request, which `verifyClient` receives as `null`.

The server checks that PKCE is given; compare the verifier with the challenge stored with the code in `exchangeAuthorizationCodeForToken`, as below. For clients that cannot use PKCE, or `S256`, yet, relax it:

```dart
@override
bool requiresPkce(PseudoApplication client) => client.id != 'legacy-app';

@override
bool get allowsPlainPkce => true;
```

The `authorizationEndpoint` injects a `Pkce` of the `code_challenge` and `code_challenge_method` of the request into its container. At the token endpoint, whose request has a `code_verifier` and no challenge, build a `Pkce` of the stored challenge instead, as below:

```dart
@override
Future<void> requestAuthorizationCode(
    PseudoApplication client,
    String? redirectUri,
    Iterable<String> scopes,
    String state,
    RequestContext req,
    ResponseContext res,
    bool implicit) async {
  // Automatically throws an error if the request doesn't contain the
  // necessary information.
  var pkce = req.container!.make<Pkce>();

  // At this point, store `pkce.codeChallenge` and `pkce.codeChallengeMethod`,
  // so that when it's time to exchange the auth code for a token, we can
  // create a [Pkce] object, and verify the client.
  await storeChallengeSomehow(client, pkce.codeChallenge, pkce.codeChallengeMethod);
}

@override
Future<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
    PseudoApplication? client,
    String? authCode,
    String? redirectUri,
    RequestContext req,
    ResponseContext res) async {
  // When exchanging the authorization code for a token, we'll need
  // a `code_verifier` from the client, so that we can ensure
  // that the correct client is trying to use the auth code.
  //
  // If none is present, an OAuth2 exception is thrown.
  var codeVerifier = await getPkceCodeVerifier(req);

  // Next, we'll need to retrieve the code challenge and code challenge method
  // from earlier.
  var codeChallenge = await getTheChallenge();
  var codeChallengeMethod = await getTheChallengeMethod();

  // Make a [Pkce] object.
  var pkce = Pkce(codeChallengeMethod, codeChallenge);

  // Call `validate`. If the client is invalid, it throws an OAuth2 exception.
  pkce.validate(codeVerifier);

  // If we reach here, we know that the `code_verifier` was valid,
  // so we can return our authorization token as per usual.
  return AuthorizationTokenResponse('...');
}
```

## Protecting Resources

Once a client has an access token, it sends it to your API in an `Authorization: Bearer` header (RFC 6750). `requireToken` protects the handlers after it: implement `findAccessToken` to look up the tokens that your grant methods issue, with their client, user, scopes and expiry, or to return `null` for one that is unknown or revoked.

```dart
@override
Future<AccessToken<PseudoApplication, PseudoUser>?> findAccessToken(
    String token, RequestContext req) async {
  var stored = await lookUpTokenSomehow(token);
  if (stored == null) return null;
  return AccessToken(
    client: stored.client,
    user: stored.user, // `null` for a client credentials grant
    scopes: stored.scopes,
    expiresAt: stored.expiresAt,
  );
}
```

```dart
app.get('/me', chain([
  server.requireToken(scopes: ['profile']),
  (req, res) {
    var token =
        req.container!.make<AccessToken<PseudoApplication, PseudoUser>>();
    return token.user;
  },
]));
```

A request that it refuses gets a `WWW-Authenticate: Bearer realm="oauth2"` challenge:

- No token: a 401, without an error, as the client did not try to authenticate.
- An unknown, revoked or expired token: `invalid_token`, a 401.
- A token that does not grant the `scopes`: `insufficient_scope`, a 403, with the scopes required.
- A malformed token, or more than one: `invalid_request`, a 400.

The token is read from the header only, unless `allowFormParameter` is `true`, which reads the `access_token` of a form, of a request that is not a GET. A token in the query is never read, as it may be logged, and a warning is logged. Several `requireToken`, of a group and of its routes, may check one request, each for its own scopes.

## Revoking Tokens

A client revokes an access or refresh token, as when its user logs out, at the `revocationEndpoint` (RFC 7009). Route a POST to it, and implement `revokeToken`:

```dart
router.post('/revoke', server.revocationEndpoint);
```

```dart
@override
Future<void> revokeToken(
    PseudoApplication client,
    String token,
    String? tokenTypeHint, // `access_token`, `refresh_token`, or `null`
    RequestContext req,
    ResponseContext res) async {
  var stored = await lookUpTokenSomehow(token, tokenTypeHint);
  // Only a token of the client; nothing for an unknown one.
  if (stored != null && stored.clientId == client.id) {
    await revokeTokenAndItsGrantSomehow(stored);
  }
}
```

It authenticates the client as the `tokenEndpoint` does, a public client by its `client_id` alone, and answers a 200 without a body, whether the token was revoked or not, so that the caller learns nothing of tokens that are not its own. A request without a `token` is `invalid_request`. Look the token up by its `token_type_hint` first, and by the other type if it is not found; revoke the tokens of the same grant too, such as the access tokens of a refresh token. Throw `unsupported_token_type` (`ErrorResponse.unsupportedTokenType`) for a type of token that the server cannot revoke; without `revokeToken`, every request is.

