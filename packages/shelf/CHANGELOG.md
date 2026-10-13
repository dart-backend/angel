# Change Log

## 10.0.0-beta-1

* fix: `embedShelf(..., throwOnNullResponse: true)` no longer turns every response into a 500. The option now has no effect, as a `shelf.Handler` cannot return `null`
* fix: A request with a malformed `Content-Length`, differing `Content-Length` values, a `Transfer-Encoding` that does not end in a single `chunked`, or both `Content-Length` and `Transfer-Encoding` is now rejected with a 400 through `app.errorHandler` (it used to be a 500), as RFC 9112 asks, since such requests can be used for request smuggling. Repeated identical values are collapsed into one, so the early `maxBodySize` check still applies. The check is the new `checkRequestFraming`, and `AngelShelf.middleware` passes the checked request on to its inner handler
* test: The tests no longer use `MirrorsReflector`; the example still does, for its `ioc` handler

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
