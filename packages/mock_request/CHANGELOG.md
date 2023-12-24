# Change Log

## 8.1.0

* Updated `lints` to 3.0.0

## 8.0.0

* Require Dart >= 3.0
* Updated `http` to 1.0.0

## 7.0.1

* Fixed `BytesBuilder` warnings

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.0.0

* Skipped release

## 2.1.0

* Updated linter to `package:lints`

## 2.0.2

* Updated README
* Updated test cases

## 2.0.1

* Updated README

## 2.0.0

* Migrated to work with Dart >= 2.12 NNBD

## 1.0.7

* Prepare for upcoming Dart SDK change where `HttpHeaders` methods
`add` and `set` take an additional optional parameter `preserveHeaderCase` (thanks @domesticmouse!).

## 1.0.6

* Prepare for upcoming Dart SDK change whereby `HttpRequest` implements
  `Stream<Uint8List>` rather than `Stream<List<int>>`.

## 1.0.5

* Add `toString` to `MockHttpHeaders`.

## 1.0.4

* Fix for `ifModifiedSince`

## 1.0.3

* Dart2 fixes
* Apparently fix hangs that break Angel tests
