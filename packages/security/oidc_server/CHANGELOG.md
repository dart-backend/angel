# Change Log

## 10.0.1

### Fixes in 10.0.1

* **Docs:** The README is rewritten with subsections for signing keys, ID tokens, signing in and logout, and the client registration metadata as a table of rules and defaults

## 10.0.0

### New in 10.0.0

* **OpenID Provider:** `OpenIdServer` extends the `AuthorizationServer` of `angel3_auth_server` into an OpenID Provider (OpenID Connect Core 1.0). You implement `subjectOf`, `clientIdOf` and `claimsOf` on top of the usual `AuthorizationServer` methods. Its `signingKeys` cannot be changed after the server is built
* **Signing keys:** `OpenIdSigningKey` is an `RS256` or `ES256` key with a key id. Generate one, store its `toJson()` as a secret, and load it with `fromJwk`. RS256 signatures are blinded, and each one is checked before it is used. A key is refused when it loads if its private part does not match its public part, or if it is an RSA key under 2048 bits. A server needs at least one RS256 key
* **ID tokens:** `issueIdToken` signs an ID token with `iss`, `sub`, `aud`, `exp` and `iat`, plus the `nonce`, `auth_time` and `at_hash` of the access token when given. `IdTokenResponse` returns it with the access token. Tokens are valid for `idTokenLifetime`, 10 minutes by default
  * Pass the code's `OpenIdRequest` and the client's `OpenIdClientMetadata`, and `issueIdToken` takes the `nonce` from them, the signing algorithm (after `idTokenAlgorithmOf`, defaulting to RS256), and whether `auth_time` is required. It is required for a `max_age`, or for a client that registered `require_auth_time` or `default_max_age`; without an `authTime`, `issueIdToken` throws
  * Extra `claims` cannot override the token's own claims. Access tokens must be ASCII, and a request whose scopes leave out `openid` cannot get an ID token
* **Authorization requests:** Every authorization request that asks for the `openid` scope, or for no scope, has its OpenID Connect parameters checked through `checkAuthorizationRequest`. A malformed `prompt`, or a `max_age` that is not a whole number of seconds, is an `invalid_request` redirected to the client. `requestAuthorizationCode` receives the parsed `OpenIdRequest`, with the request's `nonce`, `prompt` and `max_age`
* **Signing in:** `OpenIdRequest.interactions` says what to do with the user before a code is issued: sign them in (they are not signed in, their sign-in is older than `max_age` or the client's `default_max_age`, or `prompt=login`), let them pick an account, or ask for consent. With `prompt=none` it throws `login_required`, `account_selection_required` or `consent_required` instead, which are redirected to the client
  * Ask it once, when the request arrives. If the user has to sign in or consent, keep the request in the server-side session under a random, single-use id, and issue the code yourself with `completeAuthorizationCode` once they have; the README shows how. Sending them back to the authorization endpoint would ask them again
  * `max_age` must be whole seconds, and is capped at `OpenIdRequest.maxMaxAge` (about 68 years). A request with no scope has its parameters checked too, since the app may grant `openid` by default, and can then get an ID token. So decide whether to issue an ID token from the scopes granted, not from `OpenIdRequest.isOpenId`, which is false for such a request
* **JWKS:** `jwksEndpoint` publishes the public keys of all `signingKeys`, so keys can be rotated
* **UserInfo:** `userInfoEndpoint` returns the `sub` and the user's claims allowed by the access token's scopes, using `standardScopeClaims` or your own `scopeClaims`. It requires an access token with the `openid` scope
* **Logout:** `endSessionEndpoint` signs a user out at a client's request (OpenID Connect RP-Initiated Logout 1.0). An `id_token_hint` must be an ID token from this provider, expired or not: signed with its keys, from its issuer, with a `sub` and an `aud`, and not a logout token. It only redirects to a `post_logout_redirect_uri` from `postLogoutRedirectUrisOf` for the client, passing back the `state`. You implement `endSession` to sign the user out; by default it refuses
* **Client registration:** `checkClientMetadata` checks and fills in the client metadata of OpenID Connect Dynamic Client Registration 1.0, and refuses features the server does not support. `post_logout_redirect_uris` follow the same rules as `redirect_uris`, through `redirectUriProblem` of `angel3_auth_server`. A `default_max_age` is capped at `OpenIdRequest.maxMaxAge`, like `max_age`. `OpenIdClientMetadata` reads the stored metadata back. Clients may register the `openid` scope even when `ServerMetadata.scopes` does not list it
* **Configuration:** `openIdConfigurationOf` and `openIdConfigurationEndpoint` serve the OpenID Provider configuration (OpenID Connect Discovery 1.0) at `openIdConfigurationPath`. It includes the `jwks_uri`, `userinfo_endpoint`, `end_session_endpoint` and `prompt_values_supported`, and says that `claims` requests and request objects are not supported. The RFC 8414 metadata lists the `openid` scope too
