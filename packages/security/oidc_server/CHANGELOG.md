# Change Log

## 10.0.0

### New in 10.0.0

* **OpenID Provider:** `OpenIdServer`, an `AuthorizationServer` of `angel3_auth_server` that is an OpenID Provider (OpenID Connect Core 1.0), of `subjectOf`, `clientIdOf` and `claimsOf` of its users and clients
* **ID tokens:** `issueIdToken` signs an ID token of `iss`, `sub`, `aud`, `exp`, `iat`, and of the `nonce`, `auth_time` and the `at_hash` of an access token, which `IdTokenResponse` gives with the access token; `idTokenLifetime` (default 10 minutes)
* **Authorization requests:** `authorizationEndpoint` gives `requestAuthorizationCode` the `OpenIdRequest` of a request, of whether it is of the `openid` scope, its `nonce`, `prompt` and `max_age`, of which malformed values are `invalid_request`
* **Signing keys:** `OpenIdSigningKey`, an `RS256` or `ES256` key of a key id, generated, or of a private JSON Web Key, which it gives back to store. `RS256` signatures are blinded, and checked before they are given out; RSA keys must be of at least 2048 bits, and a server must have an `RS256` key
* **JWKS:** `jwksEndpoint` serves the public keys of `signingKeys`, all of them, so that keys can be rotated
* **UserInfo:** `userInfoEndpoint` gives the `sub` and the claims of a user of the scopes of an access token of the `openid` scope, of `standardScopeClaims`, or `scopeClaims` of your own
* **Configuration:** `openIdConfigurationOf` and `openIdConfigurationEndpoint` serve the OpenID Provider configuration (OpenID Connect Discovery 1.0) at `openIdConfigurationPath`
* **Signing in:** `OpenIdRequest.interactions` tells whether the user must sign in again, as of `max_age`, the client's `default_max_age` or `prompt=login`, select an account, or consent; of `prompt=none`, it throws `login_required`, `account_selection_required` or `consent_required`, of `OpenIdErrors`, which the authorization endpoint redirects
* **Logout:** `endSessionEndpoint` signs a user out at the request of a client (OpenID Connect RP-Initiated Logout 1.0), of an `id_token_hint` of the provider, expired or not, and redirects only to a `post_logout_redirect_uri` of `postLogoutRedirectUrisOf` the client, with its `state`; `endSession` signs the user out, and refuses by default
* **Client registration:** `checkClientMetadata` checks the metadata of OpenID Connect Dynamic Client Registration 1.0, of its defaults, and refuses what the server does not do; `OpenIdClientMetadata` reads it back. `issueIdToken` signs with the client's algorithm, of `idTokenAlgorithmOf`, or of its new `algorithm`, or of `RS256`, of a client of none; of `requireAuthTime`, it throws of no `authTime`. Registration accepts the `openid` scope of metadata of `scopes`
* **Configuration:** It gives the `end_session_endpoint`, `prompt_values_supported`, and that `claims` requests and request objects are not supported
