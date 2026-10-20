# Change Log

## 10.0.0

* **Breaking:** `create` throws 409 if the ID already exists
* **Breaking:** `modify` and `remove` throw 409 if the record keeps changing during writes
* **Breaking:** `read`, `modify` and `remove` throw 404 for keys that are not JSON objects
* **Breaking:** The ID counter moved to `angel_redis:id:<prefix>`, so numbering restarts at 1
* `index` uses `SCAN` instead of `KEYS`
* Fixed `index` errors and stray results
* Fixed concurrent `modify` and `remove` corrupting data
* Fixed `create` with non-string IDs and auto-IDs overwriting records
* Fixed `update` ignoring write errors
* Added `batchSize` and `maxWriteAttempts` options

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

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.0.0

* Skipped release

## 2.0.1

* Updated linter to `package:lints`

## 2.0.0

* Migrated to support Dart >= 2.12 NNBD

## 1.0.0

* First version.
