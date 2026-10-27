# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `create` throws a 409 if the id already exists
* **Breaking:** `create` throws a 400 unless the id is a non-empty string or an integer
* **Breaking:** `modify` and `remove` throw a 409 if the record keeps changing during writes
* **Breaking:** `read`, `modify` and `remove` throw a 404 for keys that are not JSON objects

### New in 10.0.0

* `batchSize` and `maxWriteAttempts` options
* `index` uses `SCAN` instead of `KEYS`

### Fixes in 10.0.0

* **Index:** No more errors or stray results
* **Modify and remove:** Concurrent writes no longer corrupt data
* **Create:** Integer ids are accepted, and auto-ids no longer overwrite records. The id counter moved to `angel_redis:id:<prefix>`, continuing from the old counter
* **Update:** Write errors are reported
* **Docs:** The README tells how to install and use the package, and how to migrate from 9.x


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
