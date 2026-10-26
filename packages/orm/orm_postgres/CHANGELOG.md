# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** An error of a `transaction`, such as a `PgException` of the database or one its callback throws, is thrown as it is, where it was a `StateError('The transaction was cancelled.')` without the error or its stack trace
* **Breaking:** Requires `angel3_orm` 10, and `postgres` 3.5.20, which throws the error of a transaction rather than that of its rollback, recovers a transaction after a rollback to a savepoint, returns the rows of the statement after a failed one, and fails a transaction started from inside its own callback rather than deadlock

### New in 10.0.0

* `transaction` on the executor its callback is given runs in a savepoint of that transaction, as PostgreSQL does not nest transactions: what it does is rolled back if it throws, even when the outer callback catches its error, and committed with the outer transaction otherwise. Savepoints at one level of nesting run one at a time, as they form a stack, whichever executor of the transaction they are made with, and one made inside another runs at the next level, so it does not wait for it; a savepoint that waits for another at its level that it did not start inside itself waits forever; a savepoint whose callback leaves the transaction aborted, by catching an error of the database, is rolled back to as if the callback threw; and one that cannot be rolled back to throws the error of its rollback. A query on the transaction's executor while a savepoint of it is open is part of that savepoint. It threw a `TypeError`. Calling `transaction` on the executor of the connection from inside the callback still throws, as the connection is in use

### Fixes in 10.0.0

* **Pool:** `PostgreSqlPoolExecutor.transaction` behaves as that of `PostgreSqlExecutor`, with savepoints for a transaction nested through the executor its callback is given
* **Transactions:** A failed transaction is rolled back once, by the driver, where a second rollback that was not awaited could fail as an uncaught error, and the transaction logs its failure at `fine` rather than as a warning, as its error is thrown to the caller; `query` still logs an error of the database as a warning

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.5.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.4.0

* Added support for `<Class>Entity` and `Entity<Class>` as data model
* Migrated data modesl in test cases from `_<Class>` to  `<Class>Entity`

## 8.3.1

* Updated test cases
* Fixed issues due to breaking changes in `analyzer` 7.3.0

## 8.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release
* Take @SerializableField properties into account when generating `Query.parseRow` (#98)
* Removed dependency on `angel3_orm_test`
* Migrated test cases from `angel3_orm_test`
* Skipped test cases for nullable primary key

## 8.2.2

* Fixed analyzer warnings

## 8.2.1

* Updated dependencies

## 8.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.1.0

* Updated repository links
* Updated `lints` to 3.0.0
* Fixed linter warnings
* [BREAKING] Updated `postgres` to 3.0.0

## 8.0.0

* Require Dart >= 3.0

## 7.1.0-beta.1

* Require Dart >= 2.19

## 7.0.1

* Reduced debugging verbosity

## 7.0.0

* Require Dart >= 2.17

## 6.1.0

* Fixed #71. Restablish broken connection automatically.

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.3.0

* Updated test cases
* Fixed test cases failing on terminaless `stdout`

## 3.2.1

* Fixed null safety errors

## 3.2.0

* Added `package:postgres_pool` for connection pooling

## 3.1.0

* Updated linter to `package:lints`

## 3.0.1

* Fixed json data issue

## 3.0.0

* Fixed NNBD issues

## 3.0.0-beta.2

* Updated README

## 3.0.0-beta.1

* Migrated to support Dart >= 2.12 NNBD

## 2.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 1.1.0-beta.1

* Improvements in how transactions are handled; rethrow failed exceptions after rolling back.
* Remove deprecated executor classes.

## 1.1.0-beta

* Updates for `package:angel_orm@2.1.0-beta`.

## 1.0.0

* Bump to `1.0.0`. This package has actually been stable for several months.

## 1.0.0-dev.4

* Port tests to use `angel_orm_test`.

## 1.0.0-dev.3

* Support for `tableName`.

## 1.0.0-dev.2

* Add optional logging.

## 1.0.0-dev.1

* Changes to work with `package:angel_orm@2.0.0-dev.15`.

## 1.0.0-dev

* First version.
