# Angel3 OpenID Connect Server

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_oidc_server?include_prereleases)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/security/oidc_server/LICENSE)

Add OpenID Connect to an OAuth 2.0 server built with [`angel3_auth_server`](https://pub.dev/packages/angel3_auth_server). Your server becomes an OpenID Provider. It issues ID tokens, which tell an app who signed in, and serves its JSON Web Key Set, its configuration and its users' claims.

- [Installation](#installation)
- [Usage](#usage)
- [Signing keys](#signing-keys)
  - [Rotating keys](#rotating-keys)
  - [Timing and faults](#timing-and-faults)
- [ID tokens](#id-tokens)
  - [The authorization request](#the-authorization-request)
  - [Issuing the ID token](#issuing-the-id-token)
- [UserInfo](#userinfo)
- [Signing in: prompt and max\_age](#signing-in-prompt-and-max_age)
  - [Asking the user](#asking-the-user)
  - [Issuing the code afterwards](#issuing-the-code-afterwards)
  - [Why not go back to the authorization endpoint](#why-not-go-back-to-the-authorization-endpoint)
  - [How max\_age and the OpenID parameters are read](#how-max_age-and-the-openid-parameters-are-read)
- [Logout](#logout)
- [Client registration](#client-registration)
- [Configuration](#configuration)
- [What it does not do](#what-it-does-not-do)

## Installation

```yaml
dependencies:
  angel3_oidc_server: ^10.0.0
```

## Usage

`OpenIdServer` is an `AuthorizationServer` from `angel3_auth_server`, so it does everything that one does, PKCE included. Implement its methods as that package's README describes, and these as well:

```dart
import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_oidc_server/angel3_oidc_server.dart';

class MyProvider extends OpenIdServer<Client, User> {
  MyProvider(OpenIdSigningKey key)
    : super(issuer: Uri.parse('https://id.example.com'), signingKeys: [key]);

  /// The `client_id` of a client, which is the audience of its ID tokens.
  @override
  String clientIdOf(Client client) => client.id;

  /// The subject of a user: an id for them that never changes.
  @override
  String subjectOf(User user) => user.id;

  /// The user's claims. UserInfo gives those that a token's scopes allow.
  @override
  Map<String, dynamic> claimsOf(User user) =>
      {'name': user.name, 'email': user.email, 'email_verified': true};

  // ... plus those of AuthorizationServer: findClient, verifyClient, and so on.
}
```

Route its endpoints:

```dart
app.group('/oauth2', (router) {
  router
    ..get('/authorize', server.authorizationEndpoint)
    ..post('/authorize', server.authorizationEndpoint)
    ..post('/token', server.tokenEndpoint)
    ..get('/jwks', server.jwksEndpoint)
    ..get('/userinfo', server.userInfoEndpoint)
    ..post('/userinfo', server.userInfoEndpoint);
});
app.get(openIdConfigurationPath, server.openIdConfigurationEndpoint(
  metadata,
  jwksUri: Uri.parse('https://id.example.com/oauth2/jwks'),
  userInfoEndpoint: Uri.parse('https://id.example.com/oauth2/userinfo'),
));
```

The issuer must be an `https` URL, or an `http` URL on `localhost`, with no query or fragment, as OpenID Connect Discovery requires.

## Signing keys

ID tokens are signed with `RS256` or `ES256`. Every OpenID Provider must support `RS256`.

Generate a key once and store its `toJson()`, which is a private JSON Web Key, as a secret. Load it on each start. That way, tokens it signed stay valid across restarts, and every instance signs with the same key.

```dart
var key = OpenIdSigningKey.generate(keyId: '2026-11');
await storeSecretSomehow(json.encode(key.toJson()));

// On each start:
var loaded = OpenIdSigningKey.fromJwk(json.decode(await readSecretSomehow()));
```

- **Which key signs.** A client's ID tokens are signed with the first key of the client's algorithm. The algorithm is the `algorithm` given to `issueIdToken`, or else the one `idTokenAlgorithmOf` returns, or else the one in the `clientMetadata` given to `issueIdToken`, or else `RS256`, the OpenID Connect default.
- **What is published.** The JSON Web Key Set publishes every key, with only its public members.
- **Requirements.** RSA keys must be at least 2048 bits, and the server must have an `RS256` key.
- **Damaged keys.** A key whose private part doesn't match its public part, such as a stored key that was damaged or pasted wrongly, is refused when it loads. The check makes a test signature and verifies it with the public key, for both `RS256` and `ES256`.

### Rotating keys

`signingKeys` can't be changed while the server runs. To rotate:

1. Build the server with the new key placed first among the keys of its algorithm, for example on a restart.
2. Keep the old key in the list until the ID tokens it signed have expired, then remove it.

### Timing and faults

- **`RS256` is blinded.** `RS256` signatures use RSA blinding, as BoringSSL and OpenSSL do, so the time a signature takes reveals nothing about the key.
- **Each signature is checked.** It is verified before it is given out. This guards against a computation fault, which could leak a factor of the key.
- **Not constant-time otherwise.** The arithmetic is pure Dart.
- **`ES256` is not constant-time.** Its signatures come from `package:jose_plus`, whose curve arithmetic is not constant-time. Prefer `RS256` where timing attacks against the server are a concern.

## ID tokens

### The authorization request

An authorization request with the `openid` scope asks for an ID token. `requestAuthorizationCode` finds its `OpenIdRequest` in `req.container`, just as it finds the `Pkce`. Store its `nonce` with the code, together with the time the user authenticated.

```dart
var openId = req.container!.make<OpenIdRequest>();
// openId.isOpenId, openId.nonce, openId.prompt, openId.maxAge
```

- **Parameters are always checked.** The OpenID Connect parameters of every authorization request are checked through `checkAuthorizationRequest` from `angel3_auth_server`, whether your app reads them or not. A malformed `max_age` or `prompt` gets `invalid_request`, which the authorization endpoint redirects like its other errors.
- **`prompt=none` is the app's to answer.** Only the app knows whether the user is signed in. Call `interactions` (see [Signing in](#signing-in-prompt-and-max_age)), or the user may be prompted after all.
- **`max_age`.** The user must have authenticated within it, or authenticate again.
- **Deciding on an ID token.** Go by the scopes granted and stored with the code, not by `isOpenId`. A request with no scope is not `isOpenId`, but your app may grant it `openid` by default and then issue an ID token.

### Issuing the ID token

In `exchangeAuthorizationCodeForToken`, issue the ID token along with the access token, as an `IdTokenResponse`:

```dart
var idToken = issueIdToken(
  user: stored.user,
  client: client!,
  // Gives the nonce and max_age, and what the client registered, if it did.
  request: stored.openId,
  clientMetadata: stored.clientMetadata,
  authTime: stored.authTime,
  accessToken: accessToken,
);
return IdTokenResponse(accessToken, idToken: idToken, expiresIn: 3600);
```

**What the token contains:**

- `iss`, `sub`, `aud`, `exp` and `iat` (OpenID Connect Core §2);
- the request's `nonce`;
- `auth_time`;
- the `at_hash` of the access token;
- any `claims` of your own, such as `acr` or `amr`. They can't replace the standard claims above.

**What to pass in:**

- **`request`:** the `OpenIdRequest` stored with the code. It supplies the `nonce`.
- **`clientMetadata`:** the metadata of a client that registered itself. It supplies the client's algorithm.
- **`requireAuthTime` and `algorithm`:** set these yourself when you don't pass `clientMetadata`.

**Rules:**

- **`auth_time` may be required.** It is required if the request had a `max_age`, or the client registered `require_auth_time` or `default_max_age`. In that case `issueIdToken` throws an `ArgumentError` if `authTime` is missing, rather than issue a token without it.
- **No `openid` scope, no ID token.** It throws an `ArgumentError` for a `request` that had scopes but not `openid`.
- **Lifetime.** The token is valid for `idTokenLifetime`, 10 minutes by default.
- **Refresh token grants.** Issue an ID token with no `nonce` and no `request`, but with the `authTime` of the original sign-in. Keep that time with the refresh token, since a client with `require_auth_time` or `default_max_age` needs it in every ID token.

## UserInfo

`userInfoEndpoint` takes an access token with the `openid` scope, from an `Authorization: Bearer` header or from the form of a POST. It returns:

- the `sub` of the token's user;
- the user's claims from `claimsOf`, limited to those the token's scopes allow.

The standard scopes are `profile`, `email`, `address` and `phone`, defined in `standardScopeClaims`. Override `scopeClaims` to add scopes of your own.

Errors:

- A token with no user, such as one from the client credentials grant, gets `invalid_token`, a 401.
- A token without the `openid` scope gets `insufficient_scope`, a 403.

Its responses are not cached.

## Signing in: prompt and max_age

`OpenIdRequest.interactions` tells `requestAuthorizationCode` what to do with the user before it issues a code. It returns a set of `OpenIdInteraction`s:

- **`login`.** Sign the user in again. This happens if they aren't signed in, if they haven't signed in within the `max_age`, or if the request says `prompt=login`. When the request has no `max_age`, pass the client's `default_max_age` as `defaultMaxAge`.
- **`selectAccount`.** Let the user pick an account, for `prompt=select_account`.
- **`consent`.** Ask for the user's consent, if they haven't given it or the request says `prompt=consent`.
- **Empty.** Issue the code at once.

With `prompt=none` the user must not be prompted. In that case it throws `login_required`, `account_selection_required` or `consent_required` instead (see `OpenIdErrors`). The authorization endpoint redirects that error to the client.

### Asking the user

Call `interactions` once, when the request first arrives. If the user has to be asked something:

1. Keep what the code needs in their session on the server, under an id that is random and used only once.
2. Send them to your login page with that id.

```dart
var openId = req.container!.make<OpenIdRequest>();
var needed = openId.interactions(
  signedIn: session.user != null,
  authTime: session.authTime,
  consented: await hasConsentedSomehow(session.user, client),
);
if (needed.isNotEmpty) {
  var id = randomIdSomehow();
  session.pending[id] = (
    client: client,
    // Never null here: the endpoint gives the registered one when the
    // request left it out.
    redirectUri: redirectUri!,
    scopes: scopes.toList(),
    state: state,
    implicit: implicit,
    openId: openId,
    pkce: req.container!.make<Pkce>(),
    needed: needed,
  );
  return res.redirect('/login?pending=$id');
}
```

### Issuing the code afterwards

Once the user has done what was asked, your own handler:

1. takes the pending request out of the session, so it can only be used once;
2. issues the code without sending the user back to the authorization endpoint.

The `authTime` to store depends on what the user did:

- **They signed in just now:** use the time of that login.
- **They only consented or picked an account:** use the session's existing time, because they didn't sign in again.

```dart
var pending = session.pending.remove(req.queryParameters['pending']);
if (pending == null) throw AngelHttpException.badRequest();
var signedInNow = pending.needed.contains(OpenIdInteraction.login);
var code = await storeCodeSomehow(
  pending,
  authTime: signedInNow ? DateTime.now() : session.authTime!,
);
await res.redirect(server.completeAuthorizationCode(
  code,
  Uri.parse(pending.redirectUri),
  state: pending.state,
));
```

For an implicit request, which `allowsImplicitGrant` must allow, give the token with `completeImplicitGrant` instead.

### Why not go back to the authorization endpoint

Sending the user back to the authorization endpoint would ask them all over again:

- `prompt=login`, `select_account`, `consent` and `max_age=0` ask every time, whatever happened before.
- A `max_age` above 0 needs a sign-in within it.
- Your app could put a marker in that URL to say the user had been asked. But the user could set that marker themselves, and so skip a login the client asked for.

### How `max_age` and the OpenID parameters are read

- `max_age` must be digits only. It is capped at `OpenIdRequest.maxMaxAge`, about 68 years.
- The OpenID Connect parameters of a request whose scopes don't include `openid` are not checked, because that request isn't OpenID Connect.
- The parameters of a request with no scope, or a blank one, are checked. Your app may grant it `openid` by default and then issue an ID token.

## Logout

`endSessionEndpoint` signs a user out of the provider at a client's request (OpenID Connect RP-Initiated Logout 1.0). To set it up:

1. Route both a GET and a POST to it.
2. Give its URL to `openIdConfigurationEndpoint` as `endSessionEndpoint`.
3. Implement these two methods:

```dart
@override
Iterable<Uri> postLogoutRedirectUrisOf(Client client) =>
    OpenIdClientMetadata.of(client.metadata).postLogoutRedirectUris;

@override
Future<void> endSession(
    EndSessionRequest<Client> request, RequestContext req, ResponseContext res) async {
  await signOutSomehow(req, request.subject);
}
```

**Checks.** If any of these fails, the request gets `invalid_request`, a 400, which is never redirected:

- **`id_token_hint`:** an ID token from this provider. It must:
  - be signed with the provider's keys and have its issuer. It may have expired;
  - have the type `JWT`, or no type;
  - have a `sub` and an `aud`;
  - not be a logout token.

  These checks stop any other JWT signed with the provider's keys from passing as one.
- **`client_id`:** the audience of the hint.
- **`post_logout_redirect_uri`:** one of the client's `postLogoutRedirectUrisOf`.

**What `endSession` should do:**

- **A request without a hint could come from anyone's link.** In `endSession`, ask the user whether to sign out first, and once they agree, redirect them to `request.redirectUri`.
- **If `endSession` doesn't answer the request itself,** the user is redirected to the `post_logout_redirect_uri` with the `state`, or told that they signed out.
- **By default, `endSession` refuses** with a 403.

## Client registration

At the `registrationEndpoint` from `angel3_auth_server`, `checkClientMetadata` also checks the metadata of OpenID Connect Dynamic Client Registration 1.0, and fills in defaults:

| Metadata | Rule | Default |
| --- | --- | --- |
| `post_logout_redirect_uris` | Same rules as `redirect_uris` | none |
| `id_token_signed_response_alg` | One of the algorithms of `signingKeys` | `RS256` |
| `subject_type` | Only `public` | `public` |
| `default_max_age` | Capped at `OpenIdRequest.maxMaxAge`, like a request's `max_age` | none |
| `require_auth_time` | A boolean | `false` |
| `application_type` | `web` or `native` | `web` |
| `initiate_login_uri` | `https` | none |

Metadata for features the server doesn't have gets `invalid_client_metadata`. These features are signed or encrypted UserInfo responses, encrypted ID tokens, request objects and pairwise subjects.

To use the metadata after registration:

- Read it back with `OpenIdClientMetadata.of(registration.metadata)`, and pass it to `issueIdToken` as `clientMetadata`.
- Or return the client's algorithm from `idTokenAlgorithmOf`. `issueIdToken` then signs the client's ID tokens with the first key of that algorithm.

## Configuration

`openIdConfigurationEndpoint` serves the OpenID Provider configuration at `openIdConfigurationPath` (`/.well-known/openid-configuration`). It contains:

- the server metadata from `angel3_auth_server`;
- `jwks_uri`, `userinfo_endpoint` and `end_session_endpoint`;
- `subject_types_supported`, which is `public`;
- `id_token_signing_alg_values_supported` and `prompt_values_supported`;
- the `openid` scope, and the claims of `scopeClaims`;
- `claims_parameter_supported`, `request_parameter_supported` and `request_uri_parameter_supported`, all `false`. They are listed because their default is `true`, and the server supports neither `claims` requests nor request objects.

The issuer of the `ServerMetadata` you pass must be the server's own issuer.

## What it does not do

- The hybrid and implicit flows. ID tokens come only from the authorization code flow. Implicit grants are refused by default, as in `angel3_auth_server`.
- Request objects (`request`, `request_uri`), `claims` requests, pairwise subjects, encrypted ID tokens, and signed or encrypted UserInfo responses.
- Front-channel and back-channel logout, and session management. Logout is only through the end session endpoint.
- Checking ID tokens as a client. For the app that signs users in, use the `openId` option of `OAuth2Strategy` in [`angel3_auth_client`](https://pub.dev/packages/angel3_auth_client).
