# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Renamed from `angel3_auth_oauth2`: depend on `angel3_auth_client`, and import `package:angel3_auth_client/angel3_auth_client.dart`
* **Breaking:** Each login has a random `state`, checked on the callback (against login CSRF), kept with its PKCE code verifier in a signed, `HttpOnly` cookie of its own, scoped to the path that the route that starts the login shares with the redirect URI, which expires after the new `loginTimeout`. `authenticateCallback` refuses a callback without it, as `invalid_state` to `onError`

### New in 10.0.0

* `cookieName`, `cookieKey`, `cookieSameSite`, `loginTimeout`, `maxLogins` and `httpClient`
* `authorizationParameters`, more query parameters of the authorization URL, such as `access_type`, `prompt` or `response_mode`
* `basicAuth`, `false` to send the client secret to the token endpoint in the form (`client_secret_post`)

### Fixes in 10.0.0

* **Callback:** A `state` that is not of the form of one the strategy gives, as of a crafted link, goes to `onError` as `invalid_state`, where one of a character a cookie name may not have, such as `;` or a space, was an error of the framework. Of a strategy of `response_mode=form_post`, a posted callback whose body cannot be read, as a malformed, too large or not UTF-8 form, goes to `onError` as `invalid_request`, where it was the framework's own 400, or the start of another login; a posted form that starts a login is of its query alone, as before. Repeated query parameters of the authorization endpoint, such as `resource`, are kept, of which one was
* **HTTP clients:** Without an `httpClient`, the client of a token exchange that fails, of any error, is closed, where it was left open; the start of a login creates none
* **Login cookies:** Starting a login, or finishing one, expires the cookies of the oldest logins of the browser beyond the new `maxLogins` (default 5), so that a user who starts many cannot make the `Cookie` header of the callback too large for the server; only cookies that the strategy signed are expired, not those of another strategy of the same `cookieName`. The cookies are of the path the start of the login shares with the redirect URI, so that the start is sent them
* **Settings:** The strategy warns of `response_mode=form_post` without `SameSite.none`, and of `SameSite.none` of an `http` redirect URI, with which every login fails, and of `authorizationParameters` that it drops, as `scope`
* **Docs:** The README samples compile, and the example's `parseParamsFromGithub`, of the type of `getParameters` and of JSON values as they are, is passed, as GitHub answers the token request as a form
* **Example:** Reads the credentials of a GitHub OAuth app from `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`, where it had an app's id and secret in its source, and its `jwtKey` from `JWT_KEY`, or a random one
* **Client without a secret:** Sends its `client_id` alone to the token endpoint, rather than an empty secret, by HTTP Basic or in the form
* **Starting a login:** Redirects to the provider, where it answered `400`: a request with `code` or `error` is now the callback
* **PKCE:** Each login uses its own code verifier for the token exchange, which providers that check PKCE refused
* **`onError`:** Its result is never taken for a user (a declined login signed users in when users are maps), and is sent as the response. A malformed callback is `invalid_request`, and an unreachable provider is a `502`
* **`form_post`:** A posted callback (e.g. Sign in with Apple) is read from its form, with `cookieSameSite: SameSite.none`
* **Cookies:** Logins in two tabs no longer replace each other's, and a client without a secret signs with a random key
* **Client:** The `oauth2.Client` given to the verifier is closed once it returns, unless `httpClient` was given
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
