# Change Log

## 10.0.0

### Breaking changes

* **Breaking:** `TwitterStrategy` uses the OAuth 1.0a redirect flow, instead of an interactive PIN flow on `stdin` in its constructor. The `client` getter is removed; the new `authorization` holds the consumer credentials
* **Breaking:** `authenticateCallback` throws `TwitterAuthorizationException` instead of returning `onError`'s result, so `authenticate` runs that result as a handler

### Fixes

* **Flow:** A request with Twitter's callback parameters is the callback; every other request is redirected to Twitter, where none ever was
* **Request tokens:** Each is kept between the redirect and the callback (`requestTokenLifetime`, `maxPendingRequestTokens`), used once, and signs the access token request
* **Errors:** A callback missing parameters, and an error page from Twitter, reach `onError` instead of a 500
* **Client:** The `client` argument is used for requests to Twitter, and URLs are built with `/` on Windows too
* **Dependencies:** Requires Dart >= 3.13 and `dart_twitter_api` 0.6.0, and is back in the workspace

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.0.0

* Require Dart >= 3.8
* Updated `oauth1` to `belatuk_oauth1`
* Updated `lints` to 6.0.0
* Updated repository link
* Fixed linter warnings

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.0

* Angel 2 + Dart 2 suppport.
* Use `package:twitter` instead of `package:twit`.
* Add `TwitterAuthorizationException`.
* Add `onError` callback.
