# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Each login has a random `state`, checked on the callback (against login CSRF), kept with its PKCE code verifier in a signed, `HttpOnly` cookie of its own, scoped to the redirect URI's path, which expires after the new `loginTimeout`. `authenticateCallback` refuses a callback without it, as `invalid_state` to `onError`

### New in 10.0.0

* `cookieName`, `cookieKey`, `cookieSameSite`, `loginTimeout` and `httpClient`

### Fixes in 10.0.0

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
