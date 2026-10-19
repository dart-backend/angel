# Change Log

## 10.0.0

* **Breaking:** `MySqlExecutor` uses [`mysql_dart`](https://pub.dev/packages/mysql_dart) 3, a maintained fork of `mysql_client`, which supports MySQL 9 and MariaDB 11, instead of `mysql_client`. It takes the `MySQLConnection` of `mysql_dart`: change `import 'package:mysql_client/mysql_client.dart'` to `import 'package:mysql_dart/mysql_dart.dart'`. The commands of a connection, of all its `MySqlExecutor`s, run one at a time, as `mysql_dart` rejects a command sent while another runs, or fails to decode its response, where `mysql_client` queued them; queries sent at once, as by `Future.wait`, still run, in turn, and `close` closes the connection once those given before it have run. A transaction holds one turn of the connection, and its queries run one at a time in a queue of its own; a transaction of its executor is of the one it is in, as MySQL nests none, and the executor runs no query once its transaction has ended, which throws a `StateError`
* fix: A query given in a transaction to another executor of its connection, such as that of the application, runs in the transaction, as does a transaction begun with it, where it waited for the transaction, which waited for it, forever. The executor given to a transaction of `MariaDbExecutor` is a `MariaDbExecutor`, and that of a transaction throws a `StateError` on `close`, which closed the connection in the transaction
* `MySqlExecutor` has the public `logger` of `MariaDbExecutor`. A zero date or time (`0000-00-00`) is read as `null`, and an insert is found whatever the case of its `INSERT`
* docs: The README tells how a `date` column may be stored as the day before or after, and how the queries of a transaction run
* **Breaking:** `MariaDbExecutor` uses `mysql_dart`, instead of [`mysql1`](https://pub.dev/packages/mysql1), which is no longer a dependency. It takes the `MySQLConnection` of `mysql_dart`, as `MySqlExecutor` does, of which it is now a subclass, and works with MySQL as well as MariaDB; it still stores a `DateTime` as UTC, and reads a date or time column back as a UTC `DateTime`. Its queries, inserts, updates, deletes and transactions are those of `MySqlExecutor`, which fixes, of `mysql1`, the `@name` placeholders that start with another's name, the values passed in the order they were set rather than that of the SQL, the insert without an id that failed with `Length of parameters (n) does not match parameter count in query (0)`, the updated rows of a table without an `id` that were not returned, and the rows of a `delete` that were not returned. `src/orm_mariadb.dart` is a part of `src/orm_mysql.dart`, so import `package:angel3_orm_mysql/angel3_orm_mysql.dart`
* docs: The README tells how each executor stores a `DateTime`: `MySqlExecutor` as local time, and `MariaDbExecutor` as UTC, which are shifted by the offset of the time zone if one reads what the other wrote
* fix: `insert` of `MySqlExecutor` and `MariaDbExecutor` returns the row of the id given, of a key the database does not generate, as a UUID, where it returned none, and of the id the database gave the row, not the last row by id, which may be another connection's insert. The executors bind the `@angel3_insert_id` of `angel3_orm` to the insert id, and no longer tell what a query is by its SQL (`.id=?`, `@`), which picked the wrong way of a select of a `@` in it
* fix: `MySqlExecutor` passes its parameters to `mysql_dart` as a list of positional `?`, found by `replacePlaceholders` of `angel3_orm`, where it named them after the columns as `:name`, which `mysql_client` only found in ASCII: a column such as `prix_unité` failed with `There is no parameter with name: prix_unit`. It no longer changes the `DateTime` values in the map it is given to local time
* fix: `MySqlExecutor` returns the updated rows of a table without an `id`; the query that selects them again was sent with its `@name` placeholders unbound
* Both executors find the `@name` placeholders with `replacePlaceholders` of `angel3_orm`
* test: `dart_test.yaml` runs the test files one at a time, as they create and drop the same tables in the same database
* test: `performance_test.dart` has a `main`, so the test runner can load (and skip) it
* test: `executor_test.dart` runs inserts, updates and selects through both `MySqlExecutor` and `MariaDbExecutor`

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
