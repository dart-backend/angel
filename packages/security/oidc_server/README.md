# Angel3 OpenID Connect Server

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_oidc_server?include_prereleases)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/security/oidc_server/LICENSE)

OpenID Connect for an OAuth 2.0 server of [`angel3_auth_server`](https://pub.dev/packages/angel3_auth_server): an OpenID Provider that issues ID tokens, which tell an app who signed in, and serves its JSON Web Key Set, its configuration and the claims of its users.

- [Installation](#installation)
- [Usage](#usage)
- [Signing keys](#signing-keys)
- [ID tokens](#id-tokens)
- [UserInfo](#userinfo)
- [Signing in, of prompt and max_age](#signing-in-of-prompt-and-max_age)
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

`OpenIdServer` is an `AuthorizationServer` of `angel3_auth_server`, of everything it does, PKCE and all: implement its methods as that package's README tells, and these too:

```dart
import 'package:angel3_auth_server/angel3_auth_server.dart';
import 'package:angel3_oidc_server/angel3_oidc_server.dart';

class MyProvider extends OpenIdServer<Client, User> {
  MyProvider(OpenIdSigningKey key)
    : super(issuer: Uri.parse('https://id.example.com'), signingKeys: [key]);

  /// The `client_id` of a client, the audience of its ID tokens.
  @override
  String clientIdOf(Client client) => client.id;

  /// The subject of a user: an id of them that never changes.
  @override
  String subjectOf(User user) => user.id;

  /// Their claims, of which UserInfo gives those of the scopes of a token.
  @override
  Map<String, dynamic> claimsOf(User user) =>
      {'name': user.name, 'email': user.email, 'email_verified': true};

  // ... and those of AuthorizationServer: findClient, verifyClient, and so on.
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

The issuer must be `https`, or `http` of `localhost`, and of no query nor fragment, as OpenID Connect Discovery requires.

## Signing keys

ID tokens are signed with `RS256`, which every OpenID Provider must support, or `ES256`. Generate a key once, store its `toJson()`, a private JSON Web Key, as a secret, and load it on each start, so that the tokens it signed stay valid across restarts and every instance signs alike:

```dart
var key = OpenIdSigningKey.generate(keyId: '2026-11');
await storeSecretSomehow(json.encode(key.toJson()));

// On each start:
var loaded = OpenIdSigningKey.fromJwk(json.decode(await readSecretSomehow()));
```

The first of `signingKeys` signs; the JSON Web Key Set publishes all of them, of their public members alone. To rotate, put a new key first, and remove the old one once the ID tokens it signed have expired. RSA keys must be of at least 2048 bits, and the server must have an `RS256` key.

`RS256` signatures are made with RSA blinding, as BoringSSL and OpenSSL make them, so that the time a signature takes tells nothing of the key, and each is checked before it is given out, against a fault of the computation, which could leak a factor of the key. The arithmetic is of pure Dart, and is not constant-time otherwise. `ES256` signatures are of `package:jose_plus`, whose curve arithmetic is not constant-time: prefer `RS256` where timing attacks against the server are a concern.

## ID tokens

An authorization request of the `openid` scope asks for an ID token. `requestAuthorizationCode` is given its `OpenIdRequest` in `req.container`, as it is the `Pkce`: store its `nonce` with the code, and when the user authenticated. Making it throws `invalid_request` of a malformed `max_age` or `prompt`, which the authorization endpoint redirects, as its other errors.

```dart
var openId = req.container!.make<OpenIdRequest>();
// openId.isOpenId, openId.nonce, openId.prompt, openId.maxAge
```

Of `prompt=none`, the user must not be prompted, and of `max_age`, they must have authenticated within it, or authenticate again: see [Signing in](#signing-in-of-prompt-and-max_age).

Issue the ID token with the access token in `exchangeAuthorizationCodeForToken`, as an `IdTokenResponse`:

```dart
var idToken = issueIdToken(
  user: stored.user,
  client: client!,
  nonce: stored.nonce,
  authTime: stored.authTime,
  accessToken: accessToken,
);
return IdTokenResponse(accessToken, idToken: idToken, expiresIn: 3600);
```

It has the `iss`, `sub`, `aud`, `exp` and `iat` of OpenID Connect Core §2, the `nonce` of the request, its `auth_time`, which is required if the request had a `max_age`, and the `at_hash` of the access token. It is valid for `idTokenLifetime` (default 10 minutes). Of a refresh token grant, issue one of no `nonce`, and of the `authTime` of the first.

## UserInfo

`userInfoEndpoint` gives, of an access token of the `openid` scope, of an `Authorization: Bearer` header or of the form of a POST, the `sub` of its user and their claims of `claimsOf` of the scopes of the token: `profile`, `email`, `address` and `phone`, of `standardScopeClaims`. Override `scopeClaims` to add scopes of your own. A token of no user, as of the client credentials grant, is `invalid_token`, a 401; one without the `openid` scope `insufficient_scope`, a 403. Its responses are not cached.

## Signing in, of prompt and max_age

`OpenIdRequest.interactions` tells `requestAuthorizationCode` what to do with the user before it issues a code: sign them in again, as they are not, or not since its `max_age` (or the client's `default_max_age`), or of `prompt=login`; let them select an account, of `prompt=select_account`; ask for their consent, as they have not given it, or of `prompt=consent`; or none of these, to issue the code at once. Of `prompt=none`, of which the user may not be prompted, it throws `login_required`, `account_selection_required` or `consent_required` instead, which the authorization endpoint redirects to the client:

```dart
var openId = req.container!.make<OpenIdRequest>();
var needed = openId.interactions(
  signedIn: session.user != null,
  authTime: session.authTime,
  consented: await hasConsentedSomehow(session.user, client),
);
if (needed.contains(OpenIdInteraction.login)) {
  return res.redirect('/login?return_to=${Uri.encodeComponent(req.uri.toString())}');
}
```

Ask once, before the user is prompted: of `prompt=login`, it is always a login. Give the ID token the `authTime` of the session, which a request of `max_age`, or a client of `require_auth_time`, requires.

## Logout

`endSessionEndpoint` signs a user out of the provider at the request of a client (OpenID Connect RP-Initiated Logout 1.0). Route a GET and a POST to it, give its URL to `openIdConfigurationEndpoint` as `endSessionEndpoint`, and implement:

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

Its `id_token_hint` must be an ID token of the provider, of its keys and issuer, expired or not; its `client_id` the audience of the hint; and its `post_logout_redirect_uri` one of `postLogoutRedirectUrisOf` the client, or the request is `invalid_request`, a 400, which is never redirected. A request of no hint could be of anyone's link: ask the user whether to sign out first, in `endSession`, and redirect them to `request.redirectUri` once they did. Unless `endSession` answers, the user is redirected to the `post_logout_redirect_uri`, with the `state`, or told that they signed out. By default, `endSession` refuses, a 403.

## Client registration

Of the `registrationEndpoint` of `angel3_auth_server`, `checkClientMetadata` checks the metadata of OpenID Connect Dynamic Client Registration 1.0 too, and gives its defaults: `post_logout_redirect_uris`, of the form of `redirect_uris`; `id_token_signed_response_alg`, of the algorithms of `signingKeys` (`RS256`); `subject_type`, `public` alone; `default_max_age` and `require_auth_time` (`false`); `application_type`, `web` or `native` (`web`); and `initiate_login_uri`, of `https`. Metadata of what the server does not do, such as signed or encrypted UserInfo responses, encrypted ID tokens, request objects and pairwise subjects, is `invalid_client_metadata`. Read it back of the registration with `OpenIdClientMetadata.of(registration.metadata)`, and give the client's algorithm to `idTokenAlgorithmOf`, of which `issueIdToken` signs its ID tokens with the first key of it.

## Configuration

`openIdConfigurationEndpoint` serves the OpenID Provider configuration at `openIdConfigurationPath` (`/.well-known/openid-configuration`): the server metadata of `angel3_auth_server`, and its `jwks_uri`, `userinfo_endpoint`, `end_session_endpoint`, `subject_types_supported` (`public`), `id_token_signing_alg_values_supported`, `prompt_values_supported`, the `openid` scope and the claims of `scopeClaims`, and that it supports no `claims` requests nor request objects, of `claims_parameter_supported`, `request_parameter_supported` and `request_uri_parameter_supported`, whose default is `true`. The issuer of its `ServerMetadata` must be that of the server.

## What it does not do

- The hybrid and implicit flows: ID tokens are of the authorization code flow. Implicit grants are refused by default, as by `angel3_auth_server`.
- Request objects (`request`, `request_uri`), `claims` requests, pairwise subjects, encrypted ID tokens, and signed or encrypted UserInfo responses.
- Front-channel and back-channel logout, and session management: logout is of the end session endpoint alone.
- Checking ID tokens as a client: that is the `openId` of the `OAuth2Strategy` of [`angel3_auth_client`](https://pub.dev/packages/angel3_auth_client), for the app that signs users in.
