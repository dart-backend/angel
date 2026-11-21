# Angel3 Auth Server

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_auth_server?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/security/auth_server/LICENSE)

Build a spec-compliant OAuth 2.0 authorization server with [Angel3](https://angel3-framework.web.app/). You subclass `AuthorizationServer`, fill in the parts that touch your data (clients, users, codes and tokens), and route its endpoints. The server handles the protocol: parameter checks, PKCE, client authentication, error responses and headers.

It covers the authorization code grant with PKCE, refresh tokens, the password and client credentials grants, the device authorization grant, extension grants, protected resources, token revocation and introspection, server metadata, and dynamic client registration. [`angel3_oidc_server`](https://pub.dev/packages/angel3_oidc_server) builds OpenID Connect on top of it.

- [Angel3 Auth Server](#angel3-auth-server)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Clients](#clients)
    - [The authorization endpoint](#the-authorization-endpoint)
    - [The token endpoint](#the-token-endpoint)
    - [Routes](#routes)
  - [Client Authentication](#client-authentication)
  - [Redirect URIs](#redirect-uris)
    - [Repeated parameters](#repeated-parameters)
  - [Other Grants](#other-grants)
    - [Implicit grant](#implicit-grant)
    - [Extension grants](#extension-grants)
  - [Device Authorization](#device-authorization)
  - [PKCE](#pkce)
  - [Protecting Resources](#protecting-resources)
  - [Revoking Tokens](#revoking-tokens)
  - [Introspecting Tokens](#introspecting-tokens)
  - [Server Metadata](#server-metadata)
  - [Client Registration](#client-registration)
    - [Metadata checks](#metadata-checks)
    - [Managing Registrations](#managing-registrations)
  - [Mutual TLS](#mutual-tls)
    - [Authenticating clients by certificate](#authenticating-clients-by-certificate)
    - [Certificate-bound access tokens](#certificate-bound-access-tokens)
    - [Behind a reverse proxy](#behind-a-reverse-proxy)
    - [Metadata and registration](#metadata-and-registration)
  - [Extending](#extending)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_framework: ^10.2.0
  angel3_auth_server: ^10.1.0
```

## Usage

The server is generic over two types of your own:

- `Client`: a third-party application that asks to access a user's account.
- `User`: a user who is signed in to your application.

### Clients

Subclass `AuthorizationServer` and implement `findClient` and `verifyClient`. `findClient` looks a client up by its `client_id`. `verifyClient` checks its `client_secret`.

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

A public client, such as a mobile app, has no secret. `verifyClient` is then given `null`, and also when the secret is empty. Return `true` for `null` only for clients that are allowed to have no secret:

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

See [Client Authentication](#client-authentication) for how the token endpoint reads the client's credentials.

### The authorization endpoint

When a user arrives at the authorization endpoint, the server checks the request and calls `requestAuthorizationCode`. This is usually where you show a consent dialog. `implicit` is `true` when the client asks for an implicit grant, which only happens if `allowsImplicitGrant` allows it (see [Implicit grant](#implicit-grant)).

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

Once the user grants access:

1. Issue a code.
2. Store it with the client, the `redirect_uri`, the scopes and the PKCE challenge (see [PKCE](#pkce)).
3. Redirect the user with `completeAuthorizationCode`. It adds the `code` and the `state` to the redirect URI and keeps the URI's own query (RFC 6749 §4.1.2).

```dart
await res.redirect(
  completeAuthorizationCode(code, Uri.parse(redirectUri!), state: state),
);
```

For an implicit grant, `completeImplicitGrant` does the same with a token, which goes in the fragment.

### The token endpoint

The client then exchanges the code for an access token, and optionally a refresh token, in `exchangeAuthorizationCodeForToken`. Two things are up to you:

- **The redirect URI.** `redirectUri` is `null` if the token request gives none. If the authorization request gave one, the token request must give the same one (RFC 6749 §4.1.3), so compare it with the one stored with the code.
- **The PKCE verifier.** The server only checks that the request gives a `code_verifier`. Compare it with the challenge stored with the code, or PKCE protects nothing. Also refuse a verifier for a code that was issued without a challenge, because the challenge may have been stripped from the authorization request (RFC 9700 §4.8.2).

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
    // A verifier for a code without a challenge: the challenge may have
    // been stripped from its request (RFC 9700 §4.8.2).
    throw AuthorizationException(
      ErrorResponse(
        ErrorResponse.invalidGrant,
        'The code was not issued with a "code_challenge".',
        '',
      ),
    );
  }
  return AuthorizationTokenResponse('foo', refreshToken: 'bar');
}
```

### Routes

Route the two endpoints:

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

- The `authorizationEndpoint` reads its parameters from the query, or from the form of a POST (RFC 6749 §3.1).
- Between them, `authorizationEndpoint` and `tokenEndpoint` handle every grant type.
- Responses from the `tokenEndpoint` have `Cache-Control: no-store` and `Pragma: no-cache`. A token's `scope` is a single string of space-separated scopes (RFC 6749 §5.1).

## Client Authentication

At the token endpoint, a client authenticates in one of two ways (RFC 6749 §2.3.1):

- with an `Authorization: Basic` header;
- without that header, with `client_id` and `client_secret` in the request's form. An `Authorization` header with another scheme is ignored.

The rules:

- A public client, such as a mobile app using PKCE, sends only its `client_id`. `verifyClient` is given a `null` secret.
- A client that fails authentication gets `invalid_client`, with status 401.
- If the request has the header and also a `client_id` or `client_secret` in the form, those must match the header.
- A client without a secret may use the authorization code, password and refresh token grants. It may not use the client credentials grant, which is only for confidential clients. It gets `unauthorized_client` instead.

A client may also authenticate by a TLS client certificate instead of a secret (see [Mutual TLS](#mutual-tls)).

The device authorization, revocation and introspection endpoints authenticate clients the same way.

## Redirect URIs

By default, the server does not know your clients' redirect URIs. So an authorization request must give a `redirect_uri`, and `requestAuthorizationCode` must check it. Errors are thrown rather than redirected, because the URI might belong to an attacker.

To have the server check the URI instead, implement `registeredRedirectUri`:

- If the request gives a `redirect_uri` that is registered for the client, return it.
- If the request gives none, return the client's registered URI.
- If the URI is not registered, throw an `AuthorizationException`. This error is not redirected.

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

Once `registeredRedirectUri` returns a URI:

- the request may leave out its `redirect_uri`;
- errors are redirected to the URI. This includes an `access_denied` thrown by `requestAuthorizationCode` and an unsupported `response_type`. Any other error is logged and redirected as `server_error`.
- The redirect carries `error`, `error_description` and the request's `state`. They go in the query, or in the fragment for an implicit grant (RFC 6749 §4.1.2.1, §4.2.2.1).

### Repeated parameters

A request that gives the same parameter more than once in its query or its form, such as two `redirect_uri`s, gets `invalid_request` (RFC 6749 §3.1). An authorization request refused for this reason is never redirected. Without this check, the server would use the last value while a proxy or filter in front of it might read the first.

- Forms are checked with `RequestContext.bodyFieldsAll`, which is why `angel3_framework` 10.1.0 is needed.
- `requireToken` refuses only a repeated `access_token`, because the rest of a protected endpoint's form belongs to your app.
- A JSON body can't be checked, because the JSON parser keeps only the last value of a repeated key.

## Other Grants

By default, every grant method throws a `400 Bad Request`. At the token endpoint the error is `unsupported_grant_type`; for an authorization request it is `unsupported_response_type`. To support a grant, implement its method. Apart from the authorization code grant described above, these are available:

- `refreshAuthorizationToken`
- `resourceOwnerPasswordCredentialsGrant`
- `clientCredentialsGrant`, which is given the request's `scope`
- `requestDeviceCode` and `exchangeDeviceCodeForToken`, for the [device authorization grant](#device-authorization)

The [OAuth 2.0 specification](https://tools.ietf.org/html/rfc6749) describes each grant type in depth.

### Implicit grant

An implicit grant (`response_type=token`) is refused by default with `unsupported_response_type`. OAuth 2.1 removes it, and RFC 9700 advises against it. Its access token is sent in the fragment of the redirect URI, where it can leak, for example through the browser history. Clients should use the authorization code grant with PKCE instead.

For clients that still need it:

1. Override `allowsImplicitGrant`. The grant then goes through `requestAuthorizationCode` with `implicit` set to `true`.
2. List `token` in the `responseTypes` of your `ServerMetadata`.

```dart
@override
bool allowsImplicitGrant(PseudoApplication client) => client.id == 'legacy-spa';
```

### Extension grants

`extensionGrants` maps other grant types to handlers. A handler runs only after the client has been authenticated, as for the other grants, by `Authorization: Basic` or by `client_id` and `client_secret` in the form. This means a grant that authenticates the client another way, such as a `client_assertion` (RFC 7523), is refused before the handler runs.

A handler is given the request and the response, but not the client. Call `findClient` if you need it.

A key that names a grant the server implements itself, such as `password`, is never called; a warning is logged once. Override that grant's method instead.

## Device Authorization

A device without a browser, such as a TV or a command line tool, asks the `deviceAuthorizationEndpoint` for a device code (RFC 8628). Route a POST to it:

```dart
router.post('/device', server.deviceAuthorizationEndpoint);
```

The flow:

1. The endpoint authenticates the client as the `tokenEndpoint` does. A device is usually a public client, so it gives only its `client_id`, and `verifyClient` is given a `null` secret.
2. It returns the `DeviceCodeResponse` from `requestDeviceCode`, which is given the request's `scope`. The device shows the user its `userCode` and the `verificationUri`, where the user authorizes the device from another device.
3. The device polls the `tokenEndpoint` with `grant_type=urn:ietf:params:oauth:grant-type:device_code` and its `device_code`.
4. `exchangeDeviceCodeForToken` answers with a token once the user has authorized the device. Until then, it throws `authorization_pending`, `slow_down`, `access_denied` or `expired_token` (`ErrorResponse.authorizationPending` and so on).

If `requestDeviceCode` is not implemented, the endpoint answers `unsupported_grant_type`.

Earlier versions accepted a device code request at the `tokenEndpoint` without a `grant_type`. That request, like any token request without a `grant_type`, is now `invalid_request`. Route a `deviceAuthorizationEndpoint` and point device clients at it.

## PKCE

By default, an authorization code grant must use [PKCE](https://tools.ietf.org/html/rfc7636) with the `S256` method, as OAuth 2.1 and RFC 9700 require. This means an intercepted authorization code cannot be redeemed.

- The authorization request must give a `code_challenge` of 43 characters (the base64url of a SHA-256 hash) and `code_challenge_method=S256`. Otherwise it gets `invalid_request`. A request without a method means `plain`, which is refused.
- The token request must give a `code_verifier` of 43 to 128 characters. Otherwise it gets `invalid_request`.

`package:oauth2` and other standard clients already do this. A public client has no secret, so it sends its `client_id` in the form of its token request, and `verifyClient` is given `null`.

The server only checks that PKCE is present. You compare the verifier with the stored challenge in `exchangeAuthorizationCodeForToken`, as below. For clients that can't use PKCE, or can't use `S256` yet, relax the rules:

```dart
@override
bool requiresPkce(PseudoApplication client) => client.id != 'legacy-app';

@override
bool get allowsPlainPkce => true;
```

For a code request, the `authorizationEndpoint` puts a `Pkce`, built from the request's `code_challenge` and `code_challenge_method`, in the request's container:

- An implicit request has no PKCE.
- If the request has no challenge, because `requiresPkce` exempts the client, making the `Pkce` throws `invalid_request`.

The `tokenEndpoint` puts no `Pkce` in the container, because its request has a `code_verifier` but no challenge. Build a `Pkce` from the stored challenge instead:

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

  // Checked by the server, for a code request. A client that `requiresPkce`
  // exempts may send no challenge, and then this throws.
  var pkce = req.container!.make<Pkce>();

  // Store the challenge and its method, so that the token request can be
  // checked against them later.
  await storeChallengeSomehow(client, pkce.codeChallenge, pkce.codeChallengeMethod);
}

@override
Future<AuthorizationTokenResponse> exchangeAuthorizationCodeForToken(
    PseudoApplication? client,
    String? authCode,
    String? redirectUri,
    RequestContext req,
    ResponseContext res) async {
  // The `code_verifier` of the request. If there is none, this throws an
  // OAuth2 error.
  var codeVerifier = await getPkceCodeVerifier(req);

  // The challenge and method stored with the code.
  var codeChallenge = await getTheChallenge();
  var codeChallengeMethod = await getTheChallengeMethod();

  // `validate` throws an OAuth2 error if the verifier doesn't match.
  Pkce(codeChallengeMethod, codeChallenge).validate(codeVerifier);

  // The verifier is valid, so issue the token as usual.
  return AuthorizationTokenResponse('...');
}
```

## Protecting Resources

Once a client has an access token, it sends the token to your API in an `Authorization: Bearer` header (RFC 6750). `requireToken` protects the handlers that come after it.

Implement `findAccessToken` to look up the tokens your grant methods issue, with their client, user, scopes and expiry. Return `null` for a token that is unknown or revoked.

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

The handlers after `requireToken` find the `AccessToken` in the request's container:

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

A refused request gets a `WWW-Authenticate: Bearer realm="oauth2"` challenge. The realm can be changed with `realm`.

| Request | Response |
| --- | --- |
| No token | 401, with no error, because the client did not try to authenticate |
| An unknown, revoked or expired token | `invalid_token`, 401 |
| A token that doesn't grant the `scopes` | `insufficient_scope`, 403, with the required scopes |
| A malformed token, or more than one | `invalid_request`, 400 |

Where the token is read from:

- By default, only from the header.
- With `allowFormParameter: true`, also from the `access_token` field of a URL-encoded form, on any request that is not a GET.
- Never from the query, where it may be logged. A token in the query is ignored, and a warning is logged.

Several `requireToken`s can check one request, for example one on a group and one on a route, each for its own scopes.

## Revoking Tokens

A client revokes an access or refresh token, for example when its user logs out, at the `revocationEndpoint` (RFC 7009). Route a POST to it and implement `revokeToken`:

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
  // Only a token of this client; nothing for an unknown one.
  if (stored != null && stored.clientId == client.id) {
    await revokeTokenAndItsGrantSomehow(stored);
  }
}
```

How it behaves:

- It authenticates the client as the `tokenEndpoint` does. A public client gives only its `client_id`.
- It answers 200 with no body, whether or not the token was revoked, so a caller learns nothing about tokens that aren't its own.
- A request without a `token` gets `invalid_request`.

In `revokeToken`:

- Look the token up by its `token_type_hint` first. If it isn't found, try the other type.
- Also revoke the other tokens of the same grant, such as the access tokens issued from a refresh token.
- Throw `unsupported_token_type` (`ErrorResponse.unsupportedTokenType`) for a kind of token the server cannot revoke. If `revokeToken` is not implemented, every request gets this error.

## Introspecting Tokens

A resource server that runs separately from the authorization server, and receives opaque tokens, asks the `introspectionEndpoint` whether a token is active and what it grants (RFC 7662). Route a POST to it:

```dart
router.post('/introspect', server.introspectionEndpoint);
```

Who may call it:

- The caller authenticates as a client, as at the `tokenEndpoint`, but it must give a secret, since anyone can give a public client's id; without one it gets `invalid_client`. Register each resource server as a confidential client.
- A client may introspect only if `mayIntrospect` returns `true` for it. This stops a client that isn't a resource server, such as a web app, from learning about other clients' tokens. A client that may not introspect gets `access_denied`, with status 403.

```dart
/// The ids of the clients that are resource servers.
const resourceServers = {'orders-api', 'billing-api'};

@override
bool mayIntrospect(PseudoApplication caller, RequestContext req) =>
    resourceServers.contains(caller.id);
```

What it answers:

- It looks the `token` up with `introspectToken`, which calls `findAccessToken` by default. Override it to find refresh tokens as well, using the `token_type_hint`.
- A token that is unknown, revoked or expired gives `{"active": false}` and nothing else.
- An active token gives `active`, its `scope`, and its `exp` and `iat` (from the `expiresAt` and `issuedAt` of its `AccessToken`), plus whatever `introspectionClaims` adds. If `introspectionClaims` returns `null`, the token is reported as inactive to that caller.

```dart
@override
Map<String, dynamic>? introspectionClaims(
    PseudoApplication caller, AccessToken<PseudoApplication, PseudoUser> token) {
  // A token that is not meant for the caller is inactive to it.
  if (!isAudienceSomehow(caller, token)) return null;
  return {
    'client_id': token.client?.id,
    'username': ?token.user?.username,
    'token_type': 'Bearer',
  };
}
```

## Server Metadata

Clients and SDKs discover the server's endpoints, and what it supports, from its metadata at `/.well-known/oauth-authorization-server` (RFC 8414). Give `ServerMetadata` the URLs where you route the endpoints and the grants you implement, then route `metadataEndpoint`:

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
  // Add `none` if the server has public clients.
  clientAuthMethods: ['client_secret_basic', 'client_secret_post', 'none'],
  scopes: ['read', 'write'],
);
app.get(metadata.wellKnownPath, server.metadataEndpoint(metadata));
```

- **What the server adds.** It adds what it knows about itself: the device code grant if a `deviceAuthorizationEndpoint` is given, its `extensionGrants`, and its PKCE methods (`S256`, plus `plain` if `allowsPlainPkce`).
- **`extra`.** It adds other metadata. It is applied last, so it can replace any value.
- **The `issuer`.** It must be an `https` URL, or an `http` URL on `localhost`, with no query or fragment. Otherwise the constructor throws an `ArgumentError`.
- **An issuer with a path.** This happens with one of several servers on a host. `wellKnownPath` then puts the path after the well-known path, as in `/.well-known/oauth-authorization-server/tenant1`.
- **`metadataOf`.** It gives the metadata as a `Map`, for example to sign it or to serve it some other way.
- **`ServerMetadata.copyWith`.** See [Extending](#extending).

## Client Registration

Clients that aren't known in advance can register themselves at the `registrationEndpoint` (RFC 7591). Each one gets a client id, plus a secret unless it is public. The endpoint checks the client's metadata against the server's `ServerMetadata`, which also supplies the endpoint's URL in the server metadata:

```dart
router.post('/register', server.registrationEndpoint(metadata));
```

Implement two methods:

- **`mayRegisterClient`.** No client may register unless it accepts the initial access token from the request's `Authorization: Bearer` header. You give this token to the client's developer. For open registration, return `true` for any token, or for none. Anyone can then register, so limit how often.
- **`registerClient`.** It stores the client, so that `findClient`, `verifyClient` and `registeredRedirectUri` can find it.

```dart
@override
bool mayRegisterClient(String? initialAccessToken, RequestContext req) =>
    initialAccessToken != null && isInitialAccessTokenSomehow(initialAccessToken);

@override
Future<void> registerClient(
    ClientRegistration registration, RequestContext req) async {
  await storeClientSomehow(
    id: registration.clientId,
    // `null` for a public client. Store it hashed, like a password.
    secretHash: hashSomehow(registration.clientSecret),
    redirectUris: registration.redirectUris,
    metadata: registration.metadata,
  );
}
```

`registerClient` may also:

- throw `invalid_client_metadata` or `invalid_redirect_uri` itself;
- change `registration.metadata` to register other values, such as a different `client_name`.

Don't change a value the server checks, such as a grant type, in `metadata`; refuse it instead. The response gives those values from the registration's own fields (`grantTypes` and so on), which are what is stored.

The response is a 201 containing:

- the metadata;
- the `client_id`;
- the `client_secret`, which does not expire;
- when they were issued.

### Metadata checks

The metadata is checked before `registerClient` is called. A refusal is a 400 with `invalid_client_metadata` or `invalid_redirect_uri`.

- **Supported values.** `grant_types`, `response_types`, `token_endpoint_auth_method` and `scope` must be among the server's own, which are:
  - `grantTypes`, plus the device code and extension grants;
  - `responseTypes`;
  - `clientAuthMethods`;
  - `scopes`.

  A server that supports the `token` response type also supports the `implicit` grant type.
- **Defaults.**
  - `grant_types`: `authorization_code`. With the `token` response type it is `implicit`, plus `authorization_code` if `code` is also given.
  - `response_types`: the ones the grant types need.
  - `token_endpoint_auth_method`: `client_secret_basic`.
  - `scope`: none.
- **Grant types and response types must match.** `authorization_code` goes with `code`, and `implicit` with `token` (RFC 7591 §2.1). A public client (`none`) may not use `client_credentials`.
- **Redirect URIs.** A client with a response type must register `redirect_uris`. Each must be absolute, with no fragment, and one of:
  - `https`;
  - `http`, only on `localhost`;
  - a native app's private-use scheme, which is a reverse domain name such as `com.example.app:/cb` (RFC 8252 §7.1).

  Any other scheme, such as `myapp:` or `javascript:`, is refused.
- **Mutual TLS.** See [Metadata and registration](#metadata-and-registration).
- **Other metadata.** Other RFC 7591 metadata must have the right types. Unknown metadata is kept. Values the server issues itself, such as a `client_id`, are dropped, and so is a `software_statement`, which the server does not verify.

The server checks the metadata only at registration. It doesn't know which registration a `Client` came from, so the token and authorization endpoints don't enforce it. In your grant methods, such as `clientCredentialsGrant` and `requestAuthorizationCode`, check the client's stored `grantTypes`, `responseTypes` and `tokenEndpointAuthMethod`. Throw `unauthorized_client` (`ErrorResponse.unauthorizedClient`) for anything it didn't register.

### Managing Registrations

If `managesClientRegistrations` is `true`, a client can also read, update and delete its registration (RFC 7592, which is Experimental). The `registrationEndpoint` then also issues the client:

- a `registration_access_token`;
- a `registration_client_uri`: the `registrationEndpoint` of the `ServerMetadata` followed by the `client_id`.

`registrationManagementEndpoint` serves that URI:

```dart
var manage = server.registrationManagementEndpoint(metadata);
router
  ..get('/register/:client_id', manage)
  ..put('/register/:client_id', manage)
  ..delete('/register/:client_id', manage);
```

In `registerClient`, store each registration's `registrationAccessToken` hashed, like its secret.

Implement `findRegistration`:

- It is given the client id and the token from the `Authorization: Bearer` header. Compare the token with the stored hash in constant time.
- If the token matches, return the stored registration. Its `clientSecret` and `registrationAccessToken` are `null`, because only their hashes are kept.
- Otherwise return `null`. The request then gets `invalid_token`, with status 401, whether the client exists or not, so the response reveals nothing about other clients.

The three methods:

- **GET.** It returns the registration with its registration access token, which the response must include (RFC 7592 §3). The secret is not returned, because only its hash is kept.
- **PUT.** It replaces the registration, with all of its metadata, and checks it like a new registration, so anything left out is no longer registered.
  - The request must give the client's `client_id`.
  - It may give the `client_secret`, which `verifyClient` checks.
  - It may not give values the server issues, such as the `registration_access_token`; that gets `invalid_client_metadata`.
  - `updateClient` stores the update. The update's secret and token are `null` unless new ones were issued: for a client that is no longer public, or because `rotatesClientSecretOnUpdate` or `rotatesRegistrationAccessToken` issues new ones on each update.
  - The response includes the token, whether new or not.
- **DELETE.** It passes the registration to `deleteClient`, which deletes the client and revokes its tokens. The response is a 204.

By default, `updateClient` and `deleteClient` refuse with `access_denied`, a 403, so a server can offer reads only.

## Mutual TLS

With mutual TLS (RFC 8705), a client authenticates with a TLS client certificate instead of a secret, and its access tokens can be bound to that certificate, so a stolen token is useless without the certificate's private key.

First, have the server ask clients for a certificate, with `requestClientCertificate: true` from `angel3_framework` 10.2.0, and trust the CAs that may sign one:

```dart
var context = SecurityContext()
  ..useCertificateChain('server.pem')
  ..usePrivateKey('server.key')
  ..setClientAuthorities('client_ca.pem')
  ..setTrustedCertificates('client_ca.pem');
var http = AngelHttp.fromSecurityContext(
  app,
  context,
  requestClientCertificate: true,
);
```

A certificate that doesn't verify against the trusted CAs fails the TLS handshake, so a self-signed one (`self_signed_tls_client_auth`) only reaches the server through a [reverse proxy](#behind-a-reverse-proxy) that accepts it.

### Authenticating clients by certificate

A client of mutual TLS sends its `client_id` and no secret, over a connection with its certificate. Implement `verifyClientCertificate` to check that the certificate is the client's:

```dart
@override
FutureOr<bool> verifyClientCertificate(
    PseudoApplication client, ClientCertificate certificate, RequestContext req) {
  // `tls_client_auth`: the subject the client registered, of a certificate
  // of a trusted CA. `self_signed_tls_client_auth`: a key of its JWKS. Or,
  // as here, the thumbprint of a certificate registered out of band.
  return client.certificateThumbprint == certificate.thumbprint;
}
```

How it fits with the other methods:

- **When it is called.** For a request that has a `client_id`, no secret, and a client certificate. It applies to every endpoint that authenticates clients: token, device authorization, revocation and introspection.
- **What `true` means.** The client is authenticated, and is confidential, as a client with a secret is. So it may use the client credentials grant and introspect tokens.
- **What `false` means.** `verifyClient` is then given a `null` secret, as for a public client. Return `false` from `verifyClient` for a client of mutual TLS, or it could be authenticated by its `client_id` alone.
- **A request with a secret** is authenticated by the secret, and its certificate isn't checked.
- **What a certificate gives.** `ClientCertificate` has the certificate's `der`, its `subject` (`/CN=client/O=Example`) when it comes from the TLS connection, and its `thumbprint`. `dart:io` can't read a certificate's subject alternative names, so matching `tls_client_auth_san_*` metadata needs a certificate parser of your own.

### Certificate-bound access tokens

To bind an access token, store the thumbprint of the request's certificate with it when you issue it:

```dart
@override
Future<AuthorizationTokenResponse> clientCredentialsGrant(
    PseudoApplication? client,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res) async {
  var certificate = await clientCertificateOf(req);
  var token = await issueTokenSomehow(
    client,
    scopes,
    certificateThumbprint: certificate?.thumbprint,
  );
  return AuthorizationTokenResponse(token);
}
```

Then return it from `findAccessToken` as the `certificateThumbprint` of the `AccessToken`:

- **`requireToken`** refuses a bound token with `invalid_token`, a 401, when the request doesn't present the same certificate.
- **Introspection** gives it as `"cnf": {"x5t#S256": ...}`, so a resource server can check it itself.
- **A JWT access token** should carry the same `cnf` claim.

Bind the tokens of the clients that registered `tls_client_certificate_bound_access_tokens`, or all of them if your server requires it. Also bind the refresh tokens of public clients (RFC 8705 §4), and check them in `refreshAuthorizationToken`.

### Behind a reverse proxy

When a proxy terminates TLS, the server's connection is to the proxy, so `RequestContext.clientCertificate` is `null`. Configure the proxy to verify the client's certificate and forward it in a header, and override `clientCertificateOf` to read it:

```dart
@override
FutureOr<ClientCertificate?> clientCertificateOf(RequestContext req) {
  // As of nginx's `proxy_set_header X-Client-Cert $ssl_client_escaped_cert;`.
  var pem = req.headers?.value('x-client-cert');
  return pem == null
      ? null
      : ClientCertificate.fromPem(Uri.decodeComponent(pem));
}
```

Only the proxy may set that header. Make the proxy replace it on every request, and don't let clients reach the server except through the proxy, or any client can claim any certificate. A certificate of `ClientCertificate.fromPem` has no `subject`.

The configurations below terminate TLS, verify client certificates against `client_ca.pem` (the CAs of `tls_client_auth` clients), and forward the certificate to the Angel3 server on `127.0.0.1:3000` in `X-Client-Cert`. A client without a certificate can still connect, for the endpoints that don't need one, and then no `X-Client-Cert` reaches the server, even if the client sent one.

#### nginx

nginx 1.13.5 or later, for `$ssl_client_escaped_cert` (the PEM, URL-encoded):

```nginx
server {
    listen 443 ssl;
    server_name auth.example.com;

    ssl_certificate     /etc/nginx/tls/server.pem;
    ssl_certificate_key /etc/nginx/tls/server.key;

    ssl_client_certificate /etc/nginx/tls/client_ca.pem;
    ssl_verify_client      optional;
    ssl_verify_depth       2;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host              $host;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        # Replaces the client's own X-Client-Cert. Without a client
        # certificate the value is empty, and nginx sends no header.
        proxy_set_header X-Client-Cert     $ssl_client_escaped_cert;
    }
}
```

A certificate that doesn't verify gets a `400 The SSL certificate error` from nginx, and never reaches the server.

#### Apache httpd

Apache 2.4.10 or later, with `mod_ssl`, `mod_proxy`, `mod_proxy_http` and `mod_headers`. `SSL_CLIENT_CERT` is the PEM itself, which `ClientCertificate.fromPem` reads as it is after the `Uri.decodeComponent` above:

```apache
<VirtualHost *:443>
    ServerName auth.example.com

    SSLEngine on
    SSLCertificateFile    /etc/apache2/tls/server.pem
    SSLCertificateKeyFile /etc/apache2/tls/server.key

    SSLCACertificateFile /etc/apache2/tls/client_ca.pem
    SSLVerifyClient      optional
    SSLVerifyDepth       2

    ProxyPreserveHost On
    ProxyPass        / http://127.0.0.1:3000/
    ProxyPassReverse / http://127.0.0.1:3000/
    RequestHeader set X-Forwarded-Proto "https"

    # Drop the client's own X-Client-Cert, then set it only when the
    # client presented a certificate.
    RequestHeader unset X-Client-Cert
    RequestHeader set X-Client-Cert "%{SSL_CLIENT_CERT}s" "expr=%{SSL_CLIENT_VERIFY} != 'NONE'"
</VirtualHost>
```

A certificate that doesn't verify fails the TLS handshake.

#### Accepting self-signed certificates

For `self_signed_tls_client_auth`, the proxy must forward certificates that it can't verify. Use `optional_no_ca` in place of `optional`, and forward the proxy's verdict as well:

- **nginx:** `ssl_verify_client optional_no_ca;` and `proxy_set_header X-Client-Verify $ssl_client_verify;`
- **Apache:** `SSLVerifyClient optional_no_ca` and `RequestHeader set X-Client-Verify "%{SSL_CLIENT_VERIFY}s"`

`X-Client-Verify` is then `SUCCESS` for a certificate of `client_ca.pem`, `FAILED:` and a reason (such as `FAILED:self-signed certificate`) for any other, and `NONE` without one. As every certificate now reaches the server, a `tls_client_auth` client must also have `SUCCESS`, or anyone could present a self-made certificate of its subject:

```dart
@override
FutureOr<bool> verifyClientCertificate(
    PseudoApplication client, ClientCertificate certificate, RequestContext req) {
  if (client.tokenEndpointAuthMethod == 'tls_client_auth' &&
      req.headers?.value('x-client-verify') != 'SUCCESS') {
    return false;
  }
  return client.certificateThumbprint == certificate.thumbprint;
}
```

Read `X-Client-Verify` only when the proxy sets it: with `optional`, nothing replaces it, so a client could send its own.

### Metadata and registration

- **Server metadata.** Add `tls_client_auth` and/or `self_signed_tls_client_auth` to `clientAuthMethods`. Set `tlsClientCertificateBoundAccessTokens: true` if the server binds tokens. If mutual TLS is served on other URLs, such as another host, give them in `mtlsEndpointAliases`, as `{'token_endpoint': Uri.parse('https://mtls.example.com/oauth2/token')}`.
- **`tls_client_auth`.** The client must register exactly one of `tls_client_auth_subject_dn`, `tls_client_auth_san_dns`, `tls_client_auth_san_uri`, `tls_client_auth_san_ip` and `tls_client_auth_san_email`, each a string.
- **`self_signed_tls_client_auth`.** The client must register its `jwks` (a JSON object) or `jwks_uri`.
- **No secret.** A client of either method is issued no `client_secret`. An update that switches a client to one of them gives `updateClient` a `null` secret, so delete the stored one; an update that switches it away from them issues a new secret.
- **`tls_client_certificate_bound_access_tokens`.** It must be a boolean, and may be `true` only if the server sets `tlsClientCertificateBoundAccessTokens`.

## Extending

A protocol built on OAuth 2.0, such as OpenID Connect (`angel3_oidc_server`), can check parameters and metadata the server doesn't know about through these hooks. Call `super` when you override one, so that other extensions still run.

`checkAuthorizationRequest` is given the parameters of each authorization request, from the query or from the form of a POST:

- **When it runs.** After the server has checked the client, the response type and PKCE, and before `requestAuthorizationCode`.
- **To refuse.** Throw an `AuthorizationException`, such as `invalid_request`.
- **Where the error goes.** If the client has a registered redirect URI (from `registeredRedirectUri`), the error is redirected there like the endpoint's other errors. Otherwise it is thrown.

```dart
@override
FutureOr<void> checkAuthorizationRequest(PseudoApplication client,
    Map<String, dynamic> params, String state, RequestContext req) {
  if (params['x_mode'] case var mode? when mode != 'fast') {
    throw AuthorizationException(ErrorResponse(
        ErrorResponse.invalidRequest, '"x_mode" must be "fast".', state));
  }
  return super.checkAuthorizationRequest(client, params, state, req);
}
```

`checkClientMetadata` is given the metadata of a new registration, or of a PUT that updates one:

- **When it runs.** After the request is authenticated, and before the server checks its own metadata.
- **What it returns.** The metadata, with any defaults added.
- **To refuse.** Throw an `AuthorizationException` with `invalid_client_metadata` or `invalid_redirect_uri` and status 400.
- **`current`.** On an update it is the registration as it is now, so you can refuse a change. On a new registration it is `null`.

```dart
@override
FutureOr<Map<String, dynamic>> checkClientMetadata(
    Map<String, dynamic> metadata, RequestContext req,
    {ClientRegistration? current}) async {
  var checked =
      await super.checkClientMetadata(metadata, req, current: current);
  return {'x_tier': 'free', ...checked};
}
```

Helpers:

- **`redirectUriProblem`.** It returns why a URI can't be a redirect URI under the [registration rules](#metadata-checks), or `null` if it can. Use it so that other redirect URIs, such as `post_logout_redirect_uris`, follow the same rules.
- **`loopbackHosts`.** It lists the hosts on which `http` is allowed: `localhost`, `127.0.0.1` and `::1`.
- **`ServerMetadata.copyWith`.** It changes some of the metadata, for example to add a scope. A `null` argument keeps the current value, so to remove one, build a new `ServerMetadata`.
