# Change Log

## 10.0.0-beta.1

* Released with the other Angel3 packages at 10.0.0
* Require Dart >= 3.13
* Updated `dart_twitter_api` to 0.6.0, which uses `intl` 0.20 like the rest of the workspace
* fix: **Breaking** `TwitterStrategy` now uses the OAuth 1.0a redirect flow. Its constructor used to run an interactive PIN flow (blocking on `stdin`) and sign every user's request token with the access token it got; the `client` getter it set up is removed, and the new `authorization` holds the consumer credentials
* fix: The `client` constructor argument is now used for the requests to Twitter
* fix: A request with Twitter's callback parameters (`oauth_token`/`oauth_verifier` or `denied`) is now handled as the callback. `AngelAuth` always passes options, so every request used to be treated as the callback and no request was ever redirected to Twitter
* fix: The access token request is signed with the request token's secret, kept in memory between the redirect and the callback (`requestTokenLifetime`, `maxPendingRequestTokens`). A request token can be used once
* fix: Twitter's URLs are built with `/` on every platform; on Windows they used `\`
* fix: A callback without `oauth_token` or `oauth_verifier`, and an error response from Twitter in plain text or HTML, now reach `onError` instead of failing with a 500
* fix: **Breaking** `authenticateCallback` now throws `TwitterAuthorizationException` instead of returning `onError`'s result, so `authenticate` runs that result as a handler instead of dropping it
* test: Added tests, against a fake Twitter
* chore: Back in the workspace, so it is resolved and analyzed with the other packages; removed the stale `pubspec_overrides.yaml`

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
