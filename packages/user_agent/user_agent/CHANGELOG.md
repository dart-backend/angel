# Change Log

## 10.0.0

### New in 10.0.0

* Exports `package:user_agent_analyzer`, as the README says, so `UserAgent` needs no other import

### Fixes in 10.0.0

* **`parseUserAgent`:** Can be used twice on a request, where the second use failed with a 500. The user agent is parsed once per request, also when made from a child container, and a `UserAgent` of the app's container no longer stands in for the request's. The header is trimmed, and a request without headers is a 400 instead of a null check error
* **Example:** Serves, where all of it was commented out
* **Dependencies:** `lints` is a dev dependency, where apps got it as a runtime one

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

## 7.0.0-beta.1

* Require Dart >= 2.17

## 6.0.0-beta.1

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.0.0-beta.1

* Migrated to support Dart >= 2.12 NNBD
* Upgraded from `pendantic` to `lints` linter

## 2.0.0

* Angel 2 + Dart 2 updates
