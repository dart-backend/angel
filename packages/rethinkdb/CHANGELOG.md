# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `read`, `modify`, `update` and `remove` of one record ignore `query`, which could make them reach every record it matched
* **Breaking:** `modify` and `update` act on the id in the path, not an `id` in the body: `modify` of a missing id is a 404, and `update` creates it
* **Breaking:** Requires `belatuk_rethinkdb` 2.0.0, where it allowed 1.x. A query on a closed connection throws an `RqlDriverError`, and when the server or the network closes the connection, the queries waiting for a reply fail; see its changelog

### New in 10.0.0

* A service over a query that is not a table (e.g. a `filter`) can read, modify, update and remove by id
* `changefeedStarted` completes when the changefeed listens for changes, so that a change made afterwards fires its event

### Fixes in 10.0.0

* **`index`:** No longer always fails with a `TypeError`
* **Changefeed:** Updates and removals fire `afterUpdated` and `afterRemoved`, not `afterCreated`, and work on a typed `HookedService`; errors are logged, and `close` stops the feed on the server, also one that is still starting
* **Changefeed over a single record or a limited query:** A service over, e.g., `get(id)` or `orderBy(...).limit(n)` fires the events of its changefeed, where it failed with a `TypeError` and fired none
* **`remove(null)`:** Removes only the records matching the query when `allowRemoveAll` is `false`
* **`create`:** Returns the created record, also when its id is generated; a duplicate id is a 409, and another rejected write a 400
* **`query` and `reql` callbacks:** Any function is applied, such as `(q) => q.filter(...)`, where only one typed as a `QueryCallback` was, and any other was ignored: `index` returned every record, and a server-side `remove(null)` removed them all. A callback that does not return a query is an `ArgumentError`
* **Writes on a service over a query that is not a table:** `modify` and `update` return the record also when the write moves it out of the query, where they wrote it and then failed with a 404
* **Dependencies:** Removed the unused `angel3_container`, and `belatuk_json_serializer`, which needed `dart:mirrors` and was only reached for data that is not a `Map`, which the service does not accept; the tests no longer use `MirrorsReflector`

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
