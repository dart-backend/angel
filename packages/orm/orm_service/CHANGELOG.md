# Change Log

## 10.0.0

* fix: **Security** `$sort` only accepts the query's own column names, and anything else is a 400 Bad Request. The value was written into the `ORDER BY` clause as it was, and client query parameters are applied by default (`allowQuery`), so any REST client could inject SQL, e.g. `?$sort=(CASE WHEN (SELECT ...) THEN id ELSE name END)`
* fix: `remove` with a `null` id ("remove all") removes only the records that match the query in its `params`; the query was ignored, so `remove(null, {'query': {...}})` deleted every record in the table
* fix: `modify` (PATCH) changes only the fields it is given, instead of every field (the others were set to `null`, or to whatever `readData` filled in). For data that `readData` read from a request, those are the fields in its body, so a field can still be cleared by sending `null`; otherwise, the fields that are not `null`. `update` (PUT) still replaces every field. A `modify` with nothing to change returns the record
* fix: A query parameter, which is a string, is converted to the type of its column (`int`, `double`, `bool` as `true`/`false`/`1`/`0`, `DateTime` as ISO 8601), so e.g. `?level=100` filters an `int` column; it failed with a `TypeError` (a 500). A value that cannot be converted, a value for an enum or JSON column, and a client query naming no column are a 400 Bad Request
* fix: `update` and `modify` change one record, even if the conditions of a query callback match more; they could change every matching record while returning one. A query callback runs after the data is copied into the query's values, so the values it sets are kept (they were overwritten)
* fix: `findOne` and `read` fetch one row from the database instead of every matching one (see `Query.getOne` in `angel3_orm`)
* fix: `create` throws a `StateError` naming the table when the inserted record cannot be read back, instead of an unexplained error from an empty `Optional`
* test: `remove` is tested for every case (by id, a nonexistent id, all records with and without a query, and a client not allowed to remove all); the test named "default" never called it
* fix: `readMany` works for a service whose `Id` is nullable (e.g. `int?`): the ids are passed to `isIn` as a list of the id column's type, which it requires; a `List<int?>` failed with a `TypeError`. `null` ids, which match no record, are left out; an id that is not a number for a numeric id column is a 400
* example: Connects with the same settings as the tests (`POSTGRES_HOSTNAME`, `POSTGRES_DB`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD`, without SSL unless `POSTGRES_SSL=true`); it hard-coded `localhost` and a database and password of its own, and required SSL

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

## 8.2.2

* Updated examples and test cases
* Updated README

## 8.2.1

* Updated dependencies
* [BREAKING] Updated `postgres` to 3.2.0

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

* Fixed NNBD issues

## 2.0.0-beta.1

* Migrated to support Dart >= 2.12 NNBD

## 1.0.0

* First version.
