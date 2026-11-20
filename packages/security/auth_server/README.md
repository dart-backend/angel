# Angel3 Auth Server

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_auth_server?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/security/auth_server/LICENSE)

A class containing handlers that can be used within [Angel3](https://angel3-framework.web.app/) to build a spec-compliant OAuth 2.0 server, including PKCE support.

- [Angel3 Auth Server](#angel3-auth-server)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Redirect URIs](#redirect-uris)
  - [Other Grants](#other-grants)
  - [Device Authorization](#device-authorization)
  - [PKCE](#pkce)
  - [Protecting Resources](#protecting-resources)
  - [Revoking Tokens](#revoking-tokens)
  - [Introspecting Tokens](#introspecting-tokens)
  - [Server Metadata](#server-metadata)
  - [Client Registration](#client-registration)
    - [Managing Registrations](#managing-registrations)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_framework: ^10.0.0
  angel3_auth_server: ^10.0.0
```

## Usage

Your server needs to have definitions of at least two types:

- One model that represents a third-party application (client) trying to access a user's profile.
- One that represents a user logged into the application.

Define a server class as such:

```dart
import 'dart:async';

import 'package:angel3_auth_server/angel3_auth_server.dart' as oauth2;

class MyServer extends oauth2.AuthorizationServer<Client, User> {
  @override
  FutureOr<Client>? findClient(String? clientId) => findClientSomehow(clientId);

  @override
  FutureOr<bool> verifyClient(Client client, String? clientSecret) =>
      verifySecretSomehow(client, clientSecret);
}
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

Next, write some logic to be executed whenever a user visits the authorization endpoint. In many cases, you will want to show a dialog. `implicit` is `true` when the client asks for an implicit grant, which it may only if `allowsImplicitGrant` allows it (see [Other Grants](#other-grants)):

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

Now, write logic that exchanges an authorization code for an access token, and optionally, a refresh token. `redirectUri` is `null` if the token request gives none: if the authorization request of the code gave one, the token request must give the same (RFC 6749 §4.1.3), so check it against the one stored with the code. The server checks only that the request gives a `code_verifier`: compare it with the challenge stored with the code, or PKCE protects nothing, and refuse a verifier for a code that was issued without a challenge, as the challenge may have been stripped from its request (see [PKCE](#pkce)).

```dart
@override
Future<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
  PseudoApplication? client,
  String? authCode,
  String? redirectUri,
  RequestContext req,
  ResponseContext res) async {
  var stored = await findCodeSomehow(authCode);
  // Stored for every code, unless `requiresPkce` exempts its client and it
  // sent no challenge.
  if (stored.codeChallenge != null) {
    Pkce(stored.codeChallengeMethod, stored.codeChallenge)
        .validate(await getPkceCodeVerifier(req));
  } else if (req.bodyAsMap['code_verifier'] != null) {
    // A verifier of a code of no challenge: the challenge may have been
    // stripped from its request (RFC 9700 §4.8.2).
    throw AuthorizationException(
      ErrorResponse(
        ErrorResponse.invalidGrant,
        'The code was not issued of a "code_challenge".',
        '',
      ),
    );
  }
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

An implicit grant, of `response_type=token`, is refused by default, as `unsupported_response_type`: OAuth 2.1 removes it, and RFC 9700 advises against it, as its access token is given in the fragment of the redirect URI, where it may leak, as by the browser history. Clients use the authorization code grant with PKCE instead. For clients that still use it, override `allowsImplicitGrant`; it is then requested through `requestAuthorizationCode`, with `implicit` set to `true`, and list `token` in the `responseTypes` of the `ServerMetadata`:

```dart
@override
bool allowsImplicitGrant(PseudoApplication client) => client.id == 'legacy-spa';
```

The `extensionGrants` map other grant types to their handlers. A handler runs once the client is authenticated, as for the other grants, by `Authorization: Basic` or by `client_id` and `client_secret` in the form, so a grant that authenticates the client another way, such as by a `client_assertion` (RFC 7523), is refused before it runs; it is given the request and the response, not the client, which it finds again by `findClient` if it needs it.

Read the [OAuth2 specification](https://tools.ietf.org/html/rfc6749) for in-depth information on each grant type.

## Device Authorization

A device without a browser, such as a TV or a command line tool, asks the `deviceAuthorizationEndpoint` for a device code (RFC 8628). Route a POST to it:

```dart
router.post('/device', server.deviceAuthorizationEndpoint);
```

It authenticates the client as the `tokenEndpoint` does: a public client, as a device usually is, gives its `client_id` alone, and `verifyClient` is given a `null` secret. It gives the `DeviceCodeResponse` of `requestDeviceCode`, of the `scope` of the request: show the user its `userCode`, and the `verificationUri`, on which they authorize the device on another one. The device then polls the `tokenEndpoint` with `grant_type=urn:ietf:params:oauth:grant-type:device_code` and its `device_code`, which `exchangeDeviceCodeForToken` answers with a token, once the user has authorized it, or with `authorization_pending`, `slow_down`, `access_denied` or `expired_token` (`ErrorResponse.authorizationPending`, and so on). Without `requestDeviceCode`, it is `unsupported_grant_type`.

Earlier versions took a device code request at the `tokenEndpoint`, without a `grant_type`; it is now `invalid_request`, as is any request there without one: route a `deviceAuthorizationEndpoint`, and point device clients at it.

## PKCE

An authorization code grant must use [PKCE](https://tools.ietf.org/html/rfc7636) with the `S256` method, by default, as OAuth 2.1 and RFC 9700 have it, so that an intercepted authorization code cannot be redeemed:

- The authorization request must give a `code_challenge`, of 43 characters, the base64url of a SHA-256 hash, and `code_challenge_method=S256`, or it is `invalid_request`: one without a method is `plain`, which is refused.
- The token request must give a `code_verifier`, of 43 to 128 characters, or it is `invalid_request`.

`package:oauth2` and other standard clients do so. A public client, such as a mobile app, which has no secret, sends its `client_id` in the form of its token request, which `verifyClient` receives as `null`.

The server checks that PKCE is given; compare the verifier with the challenge stored with the code in `exchangeAuthorizationCodeForToken`, as below. For clients that cannot use PKCE, or `S256`, yet, relax it:

```dart
@override
bool requiresPkce(PseudoApplication client) => client.id != 'legacy-app';

@override
bool get allowsPlainPkce => true;
```

The `authorizationEndpoint` injects a `Pkce` of the `code_challenge` and `code_challenge_method` of the request into its container, for a code request: an implicit one has no PKCE, and making it throws `invalid_request` without a challenge, as of a client that `requiresPkce` exempts and that sent none. The `tokenEndpoint` injects none: its request has a `code_verifier` and no challenge, so build a `Pkce` of the stored challenge instead, as below:

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
  // An implicit grant has no PKCE.
  if (implicit) return handleImplicitGrantSomehow(client, redirectUri, state);

  // Of a code request, checked by the server. A client exempted by
  // `requiresPkce` may send no challenge, which this throws for.
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

## Introspecting Tokens

A resource server that runs apart from the authorization server, and is given opaque tokens, asks the `introspectionEndpoint` whether a token is active, and of what (RFC 7662). Route a POST to it:

```dart
router.post('/introspect', server.introspectionEndpoint);
```

Its caller authenticates as a client, as at the `tokenEndpoint`, and must give a secret, as anyone may give the id of a public client: register each resource server as a confidential client. No client may introspect unless `mayIntrospect` returns `true` of it, so that a client that is no resource server, such as a web app, does not learn of the tokens of others; one that may not is `access_denied`, a 403:

```dart
/// The ids of the clients that are resource servers.
const resourceServers = {'orders-api', 'billing-api'};

@override
bool mayIntrospect(PseudoApplication caller, RequestContext req) =>
    resourceServers.contains(caller.id);
```

It looks the `token` up by `introspectToken`, which, by default, is `findAccessToken`; override it to find refresh tokens too, by the `token_type_hint`. A token that is unknown, revoked or expired is `{"active": false}`, of nothing more. An active one gives `active`, its `scope`, its `exp` and `iat`, of the `expiresAt` and `issuedAt` of its `AccessToken`, and what `introspectionClaims` adds:

```dart
@override
Map<String, dynamic>? introspectionClaims(
    PseudoApplication caller, AccessToken<PseudoApplication, PseudoUser> token) {
  // A token that is not for the caller is inactive to it.
  if (!isAudienceSomehow(caller, token)) return null;
  return {
    'client_id': token.client?.id,
    'username': ?token.user?.username,
    'token_type': 'Bearer',
  };
}
```

## Server Metadata

Clients and SDKs find the endpoints of the server, and what it supports, from its metadata at `/.well-known/oauth-authorization-server` (RFC 8414). Give `ServerMetadata` the URLs at which you route the endpoints, and the grants that you implement, and route `metadataEndpoint`:

```dart
var issuer = Uri.parse('https://example.com');
var metadata = ServerMetadata(
  issuer: issuer,
  authorizationEndpoint: issuer.resolve('/oauth2/authorize'),
  tokenEndpoint: issuer.resolve('/oauth2/token'),
  deviceAuthorizationEndpoint: issuer.resolve('/oauth2/device'),
  revocationEndpoint: issuer.resolve('/oauth2/revoke'),
  introspectionEndpoint: issuer.resolve('/oauth2/introspect'),
  registrationEndpoint: issuer.resolve('/oauth2/register'),
  grantTypes: ['authorization_code', 'refresh_token'],
  // `none`, if the server has public clients.
  clientAuthMethods: ['client_secret_basic', 'client_secret_post', 'none'],
  scopes: ['read', 'write'],
);
app.get(metadata.wellKnownPath, server.metadataEndpoint(metadata));
```

The server adds what it knows of itself: the device code grant, if a `deviceAuthorizationEndpoint` is given, its `extensionGrants`, and its PKCE methods, `S256`, and `plain` if `allowsPlainPkce`. `extra` adds other metadata, last, so that it may replace any. The `issuer` must be an `https` URL, or an `http` one of `localhost`, of no query nor fragment; of a path, as of one server of several on a host, `wellKnownPath` follows the well-known path with it, as `/.well-known/oauth-authorization-server/tenant1`. `metadataOf` gives the metadata as a `Map`, as to sign it, or to serve it otherwise.

## Client Registration

A client may register itself, and be given its id, and a secret unless it is public, at the `registrationEndpoint` (RFC 7591), as clients that are not known in advance do. It checks the metadata of the client against the `ServerMetadata` of the server, which the server metadata gives too:

```dart
router.post('/register', server.registrationEndpoint(metadata));
```

No client may register unless `mayRegisterClient` accepts the initial access token of its `Authorization: Bearer` header, which you give its developer; return `true` of any, or of none, for open registration, which anyone may use, so limit how often. Implement `registerClient` to store the client, so that `findClient`, `verifyClient` and `registeredRedirectUri` find it:

```dart
@override
bool mayRegisterClient(String? initialAccessToken, RequestContext req) =>
    initialAccessToken != null && isInitialAccessTokenSomehow(initialAccessToken);

@override
Future<void> registerClient(
    ClientRegistration registration, RequestContext req) async {
  await storeClientSomehow(
    id: registration.clientId,
    // `null` of a public client; store it hashed, as a password.
    secretHash: hashSomehow(registration.clientSecret),
    redirectUris: registration.redirectUris,
    metadata: registration.metadata,
  );
}
```

The metadata is checked before `registerClient` is called; a refusal is a 400 of `invalid_client_metadata` or `invalid_redirect_uri`:

- `grant_types`, `response_types`, `token_endpoint_auth_method` and `scope` must be of those of the server: of its `grantTypes`, with its device code and extension grants, of its `responseTypes`, `clientAuthMethods` and `scopes`. Their defaults are `authorization_code`, or, of the `token` response type, `implicit` (and `authorization_code` of `code` too), the response types of the grant types, `client_secret_basic`, and none. A server of the `token` response type supports the `implicit` grant type.
- The grant types and response types must be of each other: `authorization_code` of `code`, and `implicit` of `token` (RFC 7591 §2.1). A public client, of `none`, may not use `client_credentials`.
- A client of a response type must register its `redirect_uris`: absolute, of no fragment, `https`, `http` only for `localhost`, or of the private-use scheme of a native app, a reverse domain name, such as `com.example.app:/cb` (RFC 8252 §7.1); any other scheme, as `myapp:` or `javascript:`, is refused.
- The other metadata of RFC 7591 must be of its types; other metadata is kept. What the server issues, such as a `client_id`, and a `software_statement`, which it does not verify, are dropped.

The server checks the metadata only when the client registers: it does not know which registration a `Client` is of, so the token and authorization endpoints do not enforce it. Check the stored `grantTypes`, `responseTypes` and `tokenEndpointAuthMethod` of the client in the grant methods, such as `clientCredentialsGrant`, and `requestAuthorizationCode`, and throw `unauthorized_client` (`ErrorResponse.unauthorizedClient`) for one it did not register.

`registerClient` may throw `invalid_client_metadata` or `invalid_redirect_uri` itself, or change `registration.metadata` to register other values, such as a `client_name`. Refuse a value that the server checks, such as a grant type, instead of changing it in `metadata`: the response gives those of the fields of the registration, `grantTypes` and so on, which are what is stored. The response is a 201 of the metadata, the `client_id`, the `client_secret`, which does not expire, and when they were issued.

### Managing Registrations

A client may then read, update and delete its registration (RFC 7592, which is Experimental), if `managesClientRegistrations` is `true`. The `registrationEndpoint` then also issues it a `registration_access_token`, and its `registration_client_uri`, the `registrationEndpoint` of the `ServerMetadata`, followed by its `client_id`, which `registrationManagementEndpoint` serves:

```dart
var manage = server.registrationManagementEndpoint(metadata);
router
  ..get('/register/:client_id', manage)
  ..put('/register/:client_id', manage)
  ..delete('/register/:client_id', manage);
```

Store the `registrationAccessToken` of each registration hashed, as its secret, in `registerClient`, and implement `findRegistration`, which gives the stored registration of a client if the token, of the `Authorization: Bearer` header, is its, compared in constant time; or `null`, which is `invalid_token`, a 401, whether the client exists or not, so that it tells nothing of other clients. Its `clientSecret` and `registrationAccessToken` are `null`, as only their hashes are kept.

- A GET gives the registration, of its token, which the response must give (RFC 7592 §3), but not its secret, as only its hash is kept.
- A PUT replaces it, of all its metadata, as a registration is checked: what it does not give is no longer registered. It must give the `client_id` of the client, and may give its `client_secret`, which `verifyClient` verifies, but not what the server issues, such as the `registration_access_token`; or it is `invalid_client_metadata`. `updateClient` stores the update, whose secret and token are `null` unless they are new: of a client that is no longer public, or of `rotatesClientSecretOnUpdate` and `rotatesRegistrationAccessToken`, which issue new ones on each update. The response gives the token, new or not.
- A DELETE gives the registration to `deleteClient`, which deletes the client and revokes its tokens, and answers a 204.

By default, `updateClient` and `deleteClient` refuse, `access_denied`, a 403, so that a server may give only reads.
