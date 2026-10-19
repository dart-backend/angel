
# Change Log

## 10.0.0-beta.1

* fix: `AngelHttpException.fromMap` now accepts a status code sent as digits (`"404"`) or a whole double (`404.0`), instead of throwing `TypeError`. Only codes from 100 to 599 are used, `status_code` falling back to `statusCode`; anything else (including `-1`, `"0x194"` and `404.9`) becomes 500
* feat: `AngelHttpException.fromMap` and `fromJson` take an optional `fallbackStatusCode`, used instead of 500 when the map has no valid status code (and itself replaced by 500 if it is not one)
* fix: `AngelHttpException.fromMap` without a message now defaults it to `500 Internal Server Error` for a 500, the same as the constructor, and to the status code otherwise (e.g. `404`), instead of `Internal Server Error` whatever the status
* fix: `AngelHttpException.fromJson` now throws `FormatException` for JSON that is not an object, instead of `TypeError`
* fix: `AngelHttpException.toJson` now returns a copy of `errors`, so changing the map no longer changes the exception

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

## 8.0.0

* Require Dart >= 3.0

## 7.0.0

* Require Dart >= 2.17

## 6.0.1

* Updated README

## 6.0.0

* Require Dart >= 2.16
* [**Breaking**] `error` for `AngelHttpException` is no longer mandatory

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.1.0

* Upgraded to `lints` linter

## 3.0.2

* Updated LICENSE link

## 3.0.1

* Updated README

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD

## 2.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 1.1.0

* Emit `is_error` and `status_code` in `toJson()`.
* No more `camelCase` at all.

## 1.0.0+3

* Slightly relax the deserialization of `errors`.

## 1.0.0+2

* Added a backwards-compatible way to cast the `errors` List.

## 1.0.0+1

* Dart 2 updates.
