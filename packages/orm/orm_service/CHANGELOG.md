# Change Log

## 10.0.0

### Fixes

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
