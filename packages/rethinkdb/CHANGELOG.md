# Change Log

## 10.0.0

### Breaking changes

* **Breaking:** `read`, `modify`, `update` and `remove` of one record ignore `query`, which could make them reach every record it matched
* **Breaking:** `modify` and `update` act on the id in the path, not an `id` in the body: `modify` of a missing id is a 404, and `update` creates it

### New

* A service over a query that is not a table (e.g. a `filter`) can read, modify, update and remove by id

### Fixes

* **`index`:** No longer always fails with a `TypeError`
* **Changefeed:** Updates and removals fire `afterUpdated` and `afterRemoved`, not `afterCreated`, and work on a typed `HookedService`; errors are logged, and `close` cancels the feed
* **`remove(null)`:** Removes only the records matching the query when `allowRemoveAll` is `false`
* **`create`:** Returns the created records, including those with several generated keys; a duplicate id is a 409, and another rejected write a 400
* **Dependencies:** Removed the unused `angel3_container`; the tests no longer use `MirrorsReflector`

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.3.0

* Require Dart >= 3.9
* Updated dependencies to the latest release

## 8.2.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.1.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.0.1

* Updated README
* Fixed warnings

## 8.0.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 7.0.0

* Skipped release

## 6.0.0

* Skipped release

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.0.0

* Skipped release

## 2.0.0

* Migrated to support Dart >= 2.12 NNBD

## 1.1.0

* Moved to `package:rethinkdb_driver`
* Fixed references to old hooked event names
