# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Renamed from `angel3_auth_oauth2`: depend on `angel3_auth_client`, and import `package:angel3_auth_client/angel3_auth_client.dart`
* **Breaking:** Each login has a random `state`, checked on the callback (against login CSRF), kept with its PKCE code verifier in a signed, `HttpOnly` cookie of its own, scoped to the path that the route that starts the login shares with the redirect URI, which expires after the new `loginTimeout`. `authenticateCallback` refuses a callback without it, as `invalid_state` to `onError`

### New in 10.0.0

* `cookieName`, `cookieKey`, `cookieSameSite`, `cookiePath`, `loginTimeout`, `maxLogins`, `tokenTimeout` and `httpClient`; `tokenTimeout` (default 30 seconds, and positive) is how long the token endpoint may take to answer, after which the callback is a 502; `close()` closes the strategy, after which a request to it is a 503, and its own HTTP client; `cookiePath` sets the path of the cookies of logins, as behind a proxy that maps another path to the app's; one that a cookie may not have throws an `ArgumentError`, and one that is not the redirect URI's path or above it, of which every login fails, throws too
* `authorizationParameters`, more query parameters of the authorization URL, such as `access_type`, `prompt` or `response_mode`
* `basicAuth`, `false` to send the client secret to the token endpoint in the form (`client_secret_post`)
* **OpenID Connect:** `openId`, an `OpenIdOptions` of the issuer and JSON Web Key Set of an OpenID Provider, or of `OpenIdOptions.discover`, checks the ID token of each login (OpenID Connect Core 1.0 §3.1.3.7): of a key of the provider, of `RS256` or `ES256` and never `none` nor `HS256`, of its issuer, of the app as audience and `azp`, unexpired, of the `nonce` that each login now sends, and of the `at_hash` of its access token. The verifier is given the `IdToken` in `req.container`; a token that is refused goes to `onError` as `invalid_token`. `OpenIdProvider.endSessionUrl`, of the `end_session_endpoint` it discovers, signs the user out of the provider too (OpenID Connect RP-Initiated Logout 1.0)

### Fixes in 10.0.0

* **Callback:** A `state` that is not of the form of one the strategy gives, as of a crafted link, goes to `onError` as `invalid_state`, where one of a character a cookie name may not have, such as `;` or a space, was an error of the framework. Of a strategy of `response_mode=form_post`, of `authorizationParameters` or of the query of the authorization endpoint, a posted callback whose body cannot be read, as a malformed, too large or not UTF-8 form, goes to `onError` as `invalid_request`, where it was the framework's own 400, or the start of another login; a posted form that starts a login is of its query alone, as before, and so are the fields of a posted form that has no `state`, as one that starts a login of a field named `code`, which was taken for a callback. Repeated query parameters of the authorization endpoint, such as `resource`, are kept, where only the last was, but those that `authorizationParameters` replace. The cookie of a login that is refused, as one that timed out, is cleared, as that of one that is done. A callback without a `code`, and without an `error`, goes to `onError` as `invalid_request`, and a token response that cannot be read, as an error page of the provider, is a 502, as is a provider that cannot be reached, as of a TLS failure or no answer in time, which were a 500, where it was `invalid_request`; an error of the provider, as when the user refuses, goes to `onError` of its `error`, `error_description` and `error_uri`, which is left out if it is not a URI. A callback whose `state` shares the start of that of a login in progress, but is another, ends no login. A request is the callback if it has an `error`, or a `code` and a `state`, so that a link to the start of a login of a `code` of its own, as of a referral, starts it, where it was `invalid_state`, while an error of no `state` still goes to `onError` as `invalid_state`, rather than start another login; a refusal of the provider of a login that timed out, whose cookie shows it is of this browser, goes to `onError` as that refusal, where it was `invalid_state`
* **HTTP clients:** Without an `httpClient`, the strategy's own client is shared by every login, rather than one of each, which the token exchange of a failure left open
* **Login cookies:** Starting a login, or finishing one, expires the cookies of the oldest logins of the browser beyond the new `maxLogins` (default 5), so that a user who starts many cannot make the `Cookie` header of the callback too large for the server; only cookies of logins that the strategy started are expired, not those of another strategy of the same `cookieName`, or of another client of the same `cookieKey`; and a callback of no login of the browser, as of a crafted link, expires none of those in progress. `maxLogins` must be at least 1, and `loginTimeout` at least a second, of which the cookie would expire at once; the cookie's `Max-Age` is its whole seconds, rounded up, so that the browser keeps it as long as the server takes the login. A login started more than `loginTimeout` ahead of now, as of an instance whose clock is ahead, is refused as one that timed out. A cookie of a login started by `angel3_auth_oauth2` 10.0.0, which does not name its client, is taken for one of each strategy of its `cookieName` and `cookieKey`, until it expires. The cookies are of the path the start of the login shares with the redirect URI, so that the start is sent them
* **Settings:** `response_mode=form_post` without `SameSite.none`, of which every login fails, throws an `ArgumentError`; the strategy warns of `SameSite.none` of an `http` redirect URI, whose cookie browsers drop, and of `authorizationParameters` that it drops, as `scope`. A `cookieKey` of under 16 bytes, as of an unset variable of the environment, of which anyone could forge a login cookie, and a `cookieName` that a cookie may not have, throw an `ArgumentError`. The warning of a client without a secret names isolates, each of which has a random key of its own. A `cookieKey` must be of bytes, of values of 0 to 255, as of `utf8.encode`, not the code units of a `String`, of which the HMAC drops the high bits
* **Docs:** The README samples compile, and the example's `parseParamsFromGithub`, of the type of `getParameters` and of JSON values as they are, is passed, as GitHub answers the token request as a form
* **Example:** Reads the credentials of a GitHub OAuth app from `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`, where it had an app's id and secret in its source, and its `jwtKey` from `JWT_KEY`, or a random one; its verifier refuses a login of no GitHub user, as of a failed request of GitHub's API, where it was of a user of no GitHub id, the same of every such login, as is the README's
* **Client without a secret:** Sends its `client_id` alone to the token endpoint, rather than an empty secret, by HTTP Basic or in the form
* **Starting a login:** Redirects to the provider, where it answered `400`: a request with `code` or `error` is now the callback
* **PKCE:** Each login uses its own code verifier for the token exchange, which providers that check PKCE refused
* **`onError`:** Its result is never taken for a user (a declined login signed users in when users are maps), and is sent as the response. A malformed callback is `invalid_request`, and an unreachable provider is a `502`
* **`form_post`:** A posted callback (e.g. Sign in with Apple) is read from its form, with `cookieSameSite: SameSite.none`
* **Cookies:** Logins in two tabs no longer replace each other's, and a client without a secret signs with a random key
* **Client:** Logins share one HTTP client, `httpClient` or one of the strategy's own, so that connections to the provider are kept, where each made one of its own; the `oauth2.Client` given to the verifier is of it, and closing the strategy's own does nothing; a verifier that closes it closes neither, so that `httpClient` too stays open for the logins after
* **Verifier:** It may return `null`, of a `User` that is not nullable, to refuse a user, which `AngelAuth` answers as any failed login: its type is `FutureOr<User?> Function(...)`, of which a verifier of `FutureOr<User>` is one
* **`onError`:** A response that it writes but does not close is closed, so that `AngelAuth` does not answer it again, as with its `failureRedirect` or a 401, nor try another strategy
* **Docs:** The README tells how to install and use the package, and how to migrate from 9.x, how the routes are told apart and how a login is kept

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.4.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.1.1

* Updated repository link

## 8.1.0

* Updated `lints` to 3.0.0
* Fixed linter warnings

## 8.0.0

* Require Dart >= 3.0
* Issue: `oauth2` does not support `http` 1.0.0

## 7.0.1

* Updated example

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Updated linter to `package:lints`

## 4.0.2

* Updated example

## 4.0.1

* Updated README

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12.x Non NNBD

## 2.1.0

* Angel 2 + Dart 2 update
* Support for handling errors + rejections.
* Use `ExternalAuthOptions`.

## 2.0.0+1

* Meta update to improve Pub score.

## 2.0.0

* Angel 2 + Dart 2 updates.

## 1.0.2

Added `getParameters` to `AngelOAuth2Options`.
