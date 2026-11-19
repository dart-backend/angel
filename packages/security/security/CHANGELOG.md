# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `RateLimiter.handleRequest` returns what `rejectRequest` returns, as documented, where it always returned `false`. The default `rejectRequest` still throws a 429

### New in 10.0.0

* `CsrfFilter`, a middleware against cross-site request forgery: requests that change state must come from an allowed origin (`Sec-Fetch-Site`, `Origin` or `Referer`) and send back the value of the signed, session-bound `XSRF-TOKEN` cookie, in the `X-XSRF-TOKEN` header (as axios and Angular do) or a `_csrf` form field. The cookie holds an HMAC of the session id, not the id. The token of a request is a `CsrfToken` in its container. See `example/csrf.dart`
* `CookieSigner.readPayload`, the payload of a properly signed cookie

### Fixes in 10.0.0

* **Security:** `CookieSigner` compares signatures in constant time, where the time leaked how much of a forged signature was right, and signs the UTF-8 bytes of a value
* **`CookieSigner`:** A value containing `.` is verified, where it was always refused, and a signed cookie keeps its `SameSite`, where signing dropped it
* **`InMemoryRateLimiter`:** Ended windows are removed, and after the clock is set back, those that start later too, where one was kept for every user (e.g. every IP) ever seen
* **`Retry-After`:** Rounded up, and at least 1, where a client could be told to retry after 0 seconds while the window lasted
* **Docs:** The README tells how to install and use the package, and how to migrate from 9.x, and `RateLimiter` tells that requests of one user at the same time may together exceed the limit, unless the store updates windows atomically
* **Tests:** Cover `CookieSigner` and the rate limiters


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

## 7.0.0

* Require Dart >= 2.17

## 6.0.1

* Fixed AngelHttpException error

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.1.0

* Updated linter to `package:lints`

## 3.0.1

* Run `dartfmt -w .` to correct the formating
* Updated example

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD

## 2.0.0-alpha.1

* Make `ServiceRateLimiter` more fail-proof.

## 2.0.0-alpha

* Angel 2 updates. Remove previous functionality.
* Add `CookieSigner`, `RateLimiter`/`InMemoryRateLimiter`/`ServiceRateLimiter`
