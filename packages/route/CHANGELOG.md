# Change Log

## 8.5.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.4.0

* Remoeved deprecated `dart:html`
* Refactored the code to use `package:web`

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
* Fixed analyser warnings

## 8.0.0

* Require Dart >= 3.0
* Updated `build_web_compilers` to 4.0.0
* Updated `http` to 1.0.0

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Updated to 2.16.x

## 5.2.0

* Updated `package:build_runner`
* Updated `package:build_web_compiler`

## 5.1.0

* Updated to use `package:belatuk_combinator`
* Updated linter to `package:lints`

## 5.0.1

* Updated README

## 5.0.0

* Migrated to support Dart >= 2.12 NNBD

## 4.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 3.1.0+1

* Accidentally hit `CTRL-C` while uploading `3.1.0`; this version ensures everything is ok.

## 3.1.0

* Add `Router.groupAsync`

## 3.0.6

* Remove static default values for `middleware`.

## 3.0.5

* Add `MiddlewarePipelineIterator`.

## 3.0.4

* Add `RouteResult` class, which allows segments (i.e. wildcard) to
modify the `tail`.
* Add more wildcard tests.

## 3.0.3

* Support trailing text after parameters with custom Regexes.

## 3.0.2

* Support leading and trailing text for both `:parameters` and `*`

## 3.0.1

* Make the callback in `Router.group` generically-typed.

## 3.0.0

* Make `Router` and `Route` single-parameter generic.
* Remove `package:browser` dependency.
* `BrowserRouter.on` now only accepts a `String`.
* `MiddlewarePipeline.routingResults` now accepts
an `Iterable<RoutingResult>`, instead of just a `List`.
* Removed deprecated `Route.as`, as well as `Router.registerMiddleware`.
* Completely removed `Route.requestMiddleware`.

## 2.0.7

* Minor strong mode updates to work with stricter Dart 2.

## 2.0.5

* Patch to work with `combinator@1.0.0`.
