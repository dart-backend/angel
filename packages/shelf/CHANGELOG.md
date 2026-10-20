# Change Log

## 10.0.0

### Fixes

* **Security:** A request with malformed or conflicting `Content-Length` or `Transfer-Encoding` headers is a 400 (RFC 9112, against request smuggling), where it was a 500. The new `checkRequestFraming` does the check, and `ShelfRequestContext.framingError` holds its error
* **Hijacking:** An embedded shelf handler can hijack the request, with the socket, as with `shelf_io`; the client used to wait until it timed out
* **`app`:** `ShelfRequestContext` and `ShelfResponseContext` set `app`, so `ioc` works and `app.maxBodySize` applies to shelf bodies
* **Deprecated:** `throwOnNullResponse` of `embedShelf`, which turned every response into a 500, has no effect
* **Tests:** The tests and example no longer use `MirrorsReflector`

## 9.1.0-beta-4

* Require Dart >= 3.13

## 9.0.0-beta-4

* Require Dart >= 3.12

## 8.0.0-beta-3

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.0.0-beta.2

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.0.0-beta.1

* Require Dart >= 3.3
* Updated `lints` to 4.0.0
* Fixed linter warnings
* Updated repository link

## 7.0.0-beta.2

* Fixed `BytesBuilder` warnings

## 7.0.0-beta.1

* Require Dart >= 2.17

## 6.0.0-beta.2

* Fixed AngelHttpException error

## 6.0.0-beta.1

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.0.0-dev.3

* Fixed null safety warnings

## 3.0.0-dev.2

* Updated to use `package:belatuk_pretty_logging`

## 3.0.0-dev.1

* Migrated to support Dart >= 2.12 NNBD
* Updated linter to `package:lints`

## 2.1.0

* `pedantic` lints.
* Add the `AngelShelf` driver class, which allows you to embed Angel within shelf.

## 2.0.0

* Removed `supportShelf`.

## 1.2.0

* Upgraded for `>=1.1.0` compatibility.
