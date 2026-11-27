# Change Log

## 10.1.0

### New in 10.1.0

* **Tenants:** `OrmService.of` gives each call the executor of `executorOf`, a function of its params, as the database of the tenant of a request that a middleware puts in `req.serviceParams`, rather than one executor of every call. It is called once of each call that queries, after its ids are checked, as of `validateId`, and before its query; an error it throws is that of the call, and a database's error of the call is classified by its executor. The `executor` of such a service throws a `StateError` (issue 151)

* **Query parameters:** `OrmService` is a `DocumentedService` of `angel3_framework` 10.2.0, which this version requires: its `indexQueryParameters` are `$sort`, of the query's columns, and one of each column a query parameter can match, of a number, a string, a boolean or a date and time, so that `angel3_openapi` documents them. Its `errorResponses` are a `409` of `create`, `modify`, `update` and `remove`, as its errors of the database give. None if `allowQuery` is `false`

* **Ids:** `validateId`, of whether an id a client gives can be a record's, as of a UUID: one it refuses is a 404 of `read`, `update`, `modify` and `remove`, a 400 of a query's `id` and of `create`, and no record of `readMany`, before a query, where a malformed UUID was a 500 of PostgreSQL

* **Errors:** An error of the database that is of the request, as the executor classifies it (`QueryExecutor.classifyError` of `angel3_orm` 10.3.0, which this version requires), is its HTTP error: a duplicate key, as an `id` or an email that exists, or a foreign key a `409 Conflict`, and a missing or invalid value, as a malformed UUID on PostgreSQL, a `400 Bad Request`, where each was a `500`. Its message names the column or constraint, not the value; the database's error is its `error`, for the server's logs. `OrmService.httpErrorOf` gives the HTTP error of a `QueryError`

### Fixes in 10.1.0

* **Dependencies:** `postgres` is a dev dependency, of the tests only, as the service uses none of it: an app of MySQL, MariaDB or SQLite no longer depends on the PostgreSQL driver

* **`create`:** Of a model whose id is text, as a UUID, data without an `id` is a 400, where the insert failed with the database's `NOT NULL` error, a 500
* **`update` and `modify`:** The record keeps the id it is updated by, of a key the database does not generate, as a UUID, which `copyFrom` sets: `update` of data without an `id` failed with a `NOT NULL` error, and an `id` in the data, as in the body of a request, changed the record's key. A query callback may still set it
* **Tests:** Connect to the PostgreSQL server of `POSTGRES_HOST` (or `POSTGRES_HOSTNAME`) and `POSTGRES_PORT`, where the port was always 5432

## 10.0.0

### Fixes in 10.0.0

* **Security:** `$sort` accepts only the query's own column names (a 400 otherwise), where any REST client could inject SQL into `ORDER BY`
* **`remove(null)`:** Removes only the records matching the query, where it deleted every record of the table
* **`modify` (PATCH):** Changes only the fields it is given, where the others were set to `null`; `update` (PUT) still replaces every field
* **Queries:** A query parameter is converted to its column's type (`?level=100` on an `int`), where it failed with a 500; one that cannot be converted, or names no column, is a 400
* **One record:** `update` and `modify` change one record even if a query callback matches more, and keep the values the callback sets; `findOne` and `read` fetch one row
* **`readMany`:** Works with a nullable `Id`, and a non-numeric id of a numeric column is a 400
* **`create`:** Names the table when the inserted record cannot be read back
* **Example:** Connects with the same settings as the tests

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
