# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `origin: false` disables CORS, as documented, where it allowed every origin with `Access-Control-Allow-Origin: *`
* **Breaking:** A refused origin, or a request without one, gets no `Access-Control-Allow-Origin` header, where it got `false`; its preflight is still answered
* **Breaking:** Only a preflight request (`OPTIONS`, as sent, with an `Access-Control-Request-Method` header) is answered by `cors`; another `OPTIONS` request, or one made `OPTIONS` by a method override, continues to the app's handlers, where it was answered with `successStatus`
* **Breaking:** `Access-Control-Allow-Headers` is sent on preflights only, where the request's `Access-Control-Request-Headers` were also echoed on other responses
* **Breaking:** An `origin` of a type `CorsOptions` does not describe is an `ArgumentError` of the constructor, where it allowed every origin

### New in 10.0.0

* `origin` may be an async predicate, `Future<bool> Function(String)`

### Fixes in 10.0.0

* **No origin:** A request without an `Origin` header, with a predicate or `origin: true`, is answered, where it failed with a 500
* **`preflightContinue`:** Leaves the preflight response open for the handlers after `cors`, where it was closed
* **`Vary`:** `origin` is added to the `Vary` header, where it replaced it, when the origin is reflected (a refused one's response too), so caches keep the responses of each origin apart; a fixed `origin` does not vary
* **Example:** Allows headers, not a method, in `allowedHeaders`, and its `dynamicCors` no longer allows every origin
* **Docs:** `CorsOptions.credentials` tells that browsers refuse credentials with the default `origin` of `'*'`

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

* Fixed analyze error

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Upgraded to `lints` linter

## 4.0.1

* Updated README
* All 15 unit tests passed

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.0

* Updates for Dart 2 and Angel 2.
