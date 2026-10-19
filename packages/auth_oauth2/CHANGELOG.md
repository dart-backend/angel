# Change Log

## 10.0.0-beta.1

* fix: The route that starts a login (`auth.authenticate('github')`) redirects to the provider, where it was a `400`: `AngelAuth.authenticate` always passes options, which the strategy took for its callback. The strategy now tells the callback by its `code` or `error` query parameter
* fix: Each login has its own PKCE code verifier, kept until the callback, where one authorization URL was made once for every user, and the callback exchanged the code with another verifier, which a provider that checks PKCE (RFC 7636) refuses
* **Breaking:** Each login has a random `state`, checked on the callback, against login CSRF (RFC 6749 §10.12), where any code was accepted. The `state` and code verifier are kept in a signed, `HttpOnly`, `SameSite=Lax` cookie, scoped to the path of the redirect URI, which expires after the new `loginTimeout`; its name is the new `cookieName`, and its key the new `cookieKey` (by default, derived from the client secret). `authenticateCallback` refuses a callback without it, as `invalid_state` to `onError`
* fix: A malformed callback goes to `onError` as `invalid_request`, where it was a `400` or `500`, and a provider that cannot be reached is a `502`. A value returned by `onError` is sent as the response, where it was dropped
* fix: The `oauth2.Client` given to the verifier is closed once it returns, where it was never closed, unless the new `httpClient` was given, with which tokens are exchanged
* docs: The README tells how the two routes are told apart and how a login is kept, and configures `AngelAuth` with `configureServer`
* fix: The result of `onError` is never taken for a user, where, for users that are maps (or `dynamic`), a map that `onError` returned signed in a user, as for a login the user declined
* fix: A callback that is posted (`response_mode=form_post`, as of Sign in with Apple) is read from its form; the new `cookieSameSite` (default `SameSite.lax`) gives its cookie the `SameSite.none` it needs
* fix: Each login has a cookie of its own, `cookieName` followed by the start of its `state`, so that logins in two tabs do not replace each other's
* fix: The cookies of a client without a secret are signed with a random key, with a warning to pass a `cookieKey` for more than one instance, where the key was derived from the empty secret, and so that of every app
* test: `oauth2_strategy_test.dart`

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
