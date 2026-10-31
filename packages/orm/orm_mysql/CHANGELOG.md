# Change Log

## 10.0.1

### Fixes in 10.0.1

* **Time zones:** With `MariaDbExecutor`, a `where` clause on a local `DateTime` matches the rows written with it, as `angel3_orm` 10.0.1 binds it as a parameter, which is sent as UTC. With `MySqlExecutor`, which stores local time, it matches the same rows as before. Requires `angel3_orm` 10.0.1

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `MySqlExecutor` uses [`mysql_dart`](https://pub.dev/packages/mysql_dart) 3.0.3 or later (supports MySQL 9 and MariaDB 11) instead of `mysql_client`: pass its `MySQLConnection`, and import `package:mysql_dart/mysql_dart.dart`
* **Breaking:** `MariaDbExecutor` uses `mysql_dart` instead of `mysql1`, as a subclass of `MySqlExecutor`, and works with MySQL too; it still stores a `DateTime` as UTC. Import `package:angel3_orm_mysql/angel3_orm_mysql.dart`, not `src/orm_mariadb.dart`

### New in 10.0.0

* `MySqlExecutor` has a public `logger`

### Fixes in 10.0.0

* **Connections:** The commands of a connection run one at a time, in turn, as `mysql_dart` runs them; `close` waits for those given before it
* **Transactions:** A transaction holds the connection: its queries, including those not awaited, run in it, before its `COMMIT` or `ROLLBACK`. A failed transaction is logged at `fine`, with its stack trace, rather than as `severe`, as its error is thrown to the caller. So do the later queries of an operation of the ORM that one starts, such as the update of an `update` not awaited, which threw a `StateError` once the transaction ended. A transaction within one is part of it, and its executor refuses queries once it has ended; the executor it is given stores a `DateTime` as the executor called does, where it was that of the outer transaction, which may be of the other kind. A query given in a transaction to another executor of its connection runs in the transaction, instead of waiting for ever; `close` in a transaction throws a `StateError`
* **Inserts:** Return the row of the id given (e.g. a UUID) or of the insert id, not the last row by id, which may be another connection's, including an insert id of a `BIGINT UNSIGNED` above that of an `int`
* **Parameters:** Passed as positional `?` with `replacePlaceholders` of `angel3_orm`, so non-ASCII column names work and `DateTime`s in the given map are not changed
* **Values:** A zero date (`0000-00-00`), or an invalid one (`2024-02-30`), is read as `null`, rather than as another day, and `INSERT` is matched in any case. A date or time is read as a `DateTime` of its fields as stored, where one of `MariaDbExecutor` in the gap of a change to daylight saving time of the local time zone was an hour off
* **Docs:** The README tells how to install and use the package, and how to migrate from 9.x, tells how each executor stores a `DateTime` (local time or UTC), why a `date` may shift by a day, and how transactions run


## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.5.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release
* Changed `_` prefix in the models to `Entity` suffix. `_` prefix is still maintained for backward compatibility.

## 8.4.0

* Added support for `<Class>Entity` and `Entity<Class>` as data model
* Updated test cases to use `<Class>Entity` as data model

## 8.3.1

* Updated test cases
* Updated deletion to return deleted record(s)
* Fixed select and insert query returning incorrect data when the joined tables have same field names
* Fixed issues due to breaking changes in `analyzer` 7.3.0

## 8.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest releases
* Fixed issue #98: Take `@SerializableField` properties into account when generating `Query.parseRow`
* Migrated test cases from `angel3_orm_test` into the package
* Removed dependency on `angel3_orm_test`

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

## 7.1.0-beta.1

* [Breaking] Require Dart >= 2.19
* Added type check on "batch" column

## 7.0.1

* Reduced debugging verbosity

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Fixed temporal data type
* Fixed `MariaDbExcutor` transaction
* Updated to `lints` 2.0.0

## 6.0.0-beta.3

* Fixed transaction for `MariaDbExecutor`
* Fixed transaction for `MySqlExecutor`
* Fixed error for non `id` primary key
* Changed test cases to use tables instead of temporary tables to overcome limitations

## 6.0.0-beta.2

* Updated README

## 6.0.0-beta.1

* Require Dart >= 2.16
* Added support for MariaDB 10.2.x with `mysql1` driver
* Added support for MySQL 8.x.x with `mysql_client` driver

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.0.0

* Skipped release

## 2.0.0

* Skipped release

## 2.0.0-beta.3

* Updated linter to `package:lints`

## 2.0.0-beta.2

* Fixed NNBD issues

## 2.0.0-beta.1

* Migrated to support Dart >= 2.12 NNBD

## 1.0.0

* First version.
