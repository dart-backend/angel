# Change Log

## 10.0.0

* fix!: `read`, `modify`, `update` and `remove` of one record now ignore the `query` parameter. A query map failed with an error, and a query or callback replaced the record's selection, so the operation reached every record it matched
* fix!: `modify` and `update` now act on the id in the path. An `id` in the body was looked up instead, which created a new record when it was missing. `modify` of a missing id is a 404, and `update` of one creates it with that id
* feat: A service over a query that is not a table (e.g. a `filter`) can now read, modify, update and remove by id
* fix: `index` no longer always fails with a `TypeError`
* fix: Changefeed updates and removals no longer fire `afterCreated`; they now fire `afterUpdated` and `afterRemoved`. Changefeed events are now `HookedServiceEvent<String, Map<String, dynamic>, RethinkService>`, so they also work on a typed `HookedService`. A failing changefeed, or an error in a listener, is now logged instead of being an uncaught error, and `close` cancels the changefeed
* fix: `remove(null)` no longer removes every record when `allowRemoveAll` is `false` and the call comes from a client; it now removes only the records matching the query
* fix: `create` of data with an `id` now returns the created record instead of RethinkDB's write result. A write RethinkDB rejects is a 409 for a duplicate id, and a 400 otherwise
* fix: Inserts generating several keys now return the records, instead of a lazy list of reads that were never awaited
* test: The tests use the server in `RETHINKDB_HOST` (default `localhost`), and `test/bootstrap.dart` creates `testDB` as well as the `todos` table, waiting for both
* chore: Released with the other Angel3 packages at 10.0.0
* chore: Removed the unused `angel3_container` dependency; the tests no longer use `MirrorsReflector`

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
