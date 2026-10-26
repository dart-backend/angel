# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** A nested `Validator` filters its data, where keys it does not know were kept (a mass-assignment hole). With several `Validator`s on one key, the keys of each are kept
* **Breaking:** `validate` and `validateQuery` validate a request without an `app`, where they let it through unvalidated; a validator with an `AngelMatcher` then throws a `StateError`

### Fixes in 10.0.0

* **Null values:** An `AngelMatcher` or `ContextAwareMatcher` does not match `null`, where it failed with a `TypeError` (a 500, or a 400 with the error as its message)
* **`asyncApplyValidator`:** Uses the validator's `customErrorMessages`, runs the `AngelMatcher`s of nested `Validator`s, gives `AngelMatcher`s the input as their context, as `check` does, where keys without rules were missing, and takes an optional `app`
* **`validateEvent`:** Is generic, so it can be listened to on a typed service such as `MapService`; data that is not a `Map` is a 400 instead of a cast error

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

## 8.0.2

* Fixed incorrect mismatch message handling

## 8.0.1

* Fixed missing mismatch errors

## 8.0.0

* Require Dart >= 3.0

## 7.0.1

* Fixed linter warnings

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Updated linter to `package:lints`
* Updated `build_runner` to major version 2.1.0
* Updated `build_web_compilers` to major version 3.2.0

## 4.0.2

* Updated broken links in README
* All 7 unit test passed

## 4.0.1

* Updated README

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.2

* Deduplicate error messages.

## 2.0.1+1

* Fix bug in the implementation of `maxLength`.

## 2.0.1

* Patch for updated body parsing.

## 2.0.0

* Finish update for Angel 2.

## 2.0.0-alpha.1

* Update for Angel 2.

## 1.0.5-beta

* Use `wrapMatcher` on explicit values instead of throwing.
* Add async matchers.
* Add context-aware matchers.

## 1.0.4

* `isNonEmptyString` trims strings.
* `ValidationException` extends `AngelHttpException`.
* Added `requireField` and `requireFields`.
