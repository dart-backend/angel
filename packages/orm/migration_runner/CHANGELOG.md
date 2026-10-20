# Change Log

## 10.0.0

### Breaking changes

* **Breaking:** The runners no longer use `dart:mirrors`, so they run in programs compiled with `dart compile exe`. A migration is recorded by its `Migration.name` (default: its class name), where it was its absolute source path and class name, which changed when the project moved. Paths recorded by earlier versions are renamed on start (by `legacyPath`, or the only migration of the class name); an ambiguous path throws a `StateError` rather than guess. See the README
* **Breaking:** `MySqlMigrationRunner` uses [`mysql_dart`](https://pub.dev/packages/mysql_dart) 3 instead of `mysql_client`, and `MariaDbMigrationRunner` and `MariaDbSchema.run` use it instead of `mysql1`: pass its `MySQLConnection`, and import `package:mysql_dart/mysql_dart.dart`
* **Breaking:** `up` of every runner throws when a migration fails, and runs none after it, where the PostgreSQL and MariaDB runners only logged it. `MySqlSchema.run` throws when its SQL fails
* **Breaking:** Two migrations of the same name throw a `StateError`, including two of a class that takes arguments without their own `name`
* **Breaking:** **Security** String defaults are quoted and escaped alike on every database, where some were unquoted or badly escaped (an SQL injection with a crafted default). A `String` default is always a literal: give SQL as `RawSql` (`defaultsTo(RawSql('CURRENT_TIMESTAMP'))`), and give `defaultsTo('active')`, not `"'active'"`. Other defaults are literals of their `toString()`; a `DateTime` is a date literal, with its offset on PostgreSQL when UTC
* **Breaking:** `numeric` and `decimal` columns are created with their precision and scale, where MySQL and MariaDB rounded values to whole numbers; without them, `numeric(17, 3)` on MySQL and MariaDB, unbounded on PostgreSQL. A precision without a scale has a scale of 3. Values above a database's limits throw an `ArgumentError`
* **Breaking:** `changeColumnType` takes the `precision`, `scale` and `length` of the new type (default length 255), the constraints after the change, and `using` (PostgreSQL)
* **Breaking:** Table names are quoted per part: MySQL and MariaDB in backticks (`` `shop`.`orders` ``), PostgreSQL by schema (`"audit"."events"`); a name already quoted is quoted once. A PostgreSQL table with a `.` in its own name is given in double quotes. `rename` keeps a table in its schema

### New

* `SqlMigrationRunner<S>`, which all the runners extend, and `MySqlFamilyMigrationRunner`, `MySqlFamilySchema`, `MySqlFamilyGenerator`, `MySqlFamilyTable` and `MySqlFamilyIndexes`, which those of MySQL and MariaDB share
* `PostgresSchema.run` also takes a `Session`, such as a transaction
* `changeColumnType(..., defaultValue: noDefault)` removes a column's default
* Deprecated the unused `connected` parameter of the runners. Removed `ModifyingAlterTable.modifications` and the `charcode` dependency

### Fixes

* **`changeColumnType` on MySQL and MariaDB:** The column's `NOT NULL`, default, `AUTO_INCREMENT`, `ON UPDATE`, `UNSIGNED`, `COMMENT`, character set, collation, generation expression and (MariaDB) `CHECK` constraints are kept, read from `information_schema` when the schema runs, where `MODIFY` dropped them. It reads servers without `GENERATION_EXPRESSION` and Aurora's versions, drops defaults a type cannot have, and makes a serial column `AUTO_INCREMENT` only when it is a key
* **`changeColumnType` on PostgreSQL:** Keeps the column's constraints, changes to a serial type's integer with a sequence of its own (resized as needed), and handles identity columns
* **Alter tables:** Clauses on a column added, renamed or changed earlier in the same alter table run in separate statements; added columns keep their order and indexes; `setNotNull` and `dropNotNull` work on MySQL and MariaDB; `renameColumn` of MariaDB works
* **Statements:** Schemas of several statements run on every database (one by one on MySQL and MariaDB, by the simple protocol on PostgreSQL), and an alter table is no longer ended twice
* **Quoting:** Columns are quoted in every clause, so they may be reserved words; index columns are quoted only when they are names, so prefixes (`body(100)`) and expressions work; `REFERENCES` are quoted; PostgreSQL doubles quotes in identifiers
* **Indexes:** A standard index of a PostgreSQL alter table, or of a column declared with one, is created, and `dropIndex` drops an index or unique constraint. A unique index of an expression is a `CREATE UNIQUE INDEX`, and a primary key of an expression throws
* **Recording:** The paths of the `migrations` table are passed as parameters. On PostgreSQL, a migration runs and is recorded in one transaction. `rollback` and `reset` undo the newest first, once each. `NULL` paths and text batch numbers are read
* **Legacy paths:** Generic migrations, case-sensitive paths, and names with `#` are matched correctly; a migration whose `legacyPath` matches no path throws a `StateError`
* **Defaults:** Non-finite `double`s are `'NaN'`/`'Infinity'` on PostgreSQL and throw on MySQL and MariaDB; MySQL 8 expression defaults and `bit` defaults are kept
* **`runMigrations`:** Closes the runner when a migration fails, and throws that migration's error

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.5.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.4.1

* [MySQL] Generated `int` primary key as `INT NOT NULL AUTO_INCREMENT`

## 8.4.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release
* [MySQL] Fixed foreign key generation for serial primary
* [MySQL] Fixed default value generation
* [MySQL] Fixed `@Column(indexType: IndexType.unique)` generation

## 8.3.0

* Added `addIndex`, `dropIndex` and `dropPrimaryIndex`

## 8.2.2

* Fixed `MariaDbMigrationRunner` migration issues

## 8.2.1

* Updated README
* Updated examples
* Updated `PostgresMigrationRunner` error handling
* Fixed `MySqlMigrationRunner` migration issues
* Added test cases for `PostgreSQL`, `MySQL` and `MariaDB`
* Added auto increment integer primary key suppport to MySQL and MariaDB

## 8.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0
* Fixed MySQL migration column change [PR #127](https://github.com/dart-backend/angel/pull/127)

## 8.1.1

* Updated pubspec

## 8.1.0

* [BREAKING] Updated `postgres` to 3.0.0
* Updated repository link
* Updated `lints` to 3.0.0
* Fixed linter warnings

## 8.0.0

* Require Dart >= 3.0

## 7.1.0

* Require Dart >= 2.18

## 7.0.0

* Require Dart >= 2.17

## 6.1.0

* Fixed issue #70. Incorrectly generated SQL for `defaultsTo('Default Value')`
* Mapped timestamp to datetime for MySQL and MariaDB
* Fixed `MariaDbMigrationRunner` to work with MariaDB
* Fixed `MySqlMigrationRunner` to work with MySQL and MariaDB

## 6.0.1

* Added `MariaDbMigrationRunner` to support MariaDB migration with `mysql1` driver
* Updated `MySqlMigrationRunner` to support MySQL migration with `mysql_client` driver

## 6.0.0

* Require Dart >= 2.16
* Updated to use `mysql_client` package

## 5.0.0

* Skipped release

## 4.1.2

* Updated README

## 4.1.1

* Updated README

## 4.1.0

* Added support for `MySQL` and `MariaDB` database

## 4.0.2

* Updated README

## 4.0.1

* Updated linter to `package:lints`

## 4.0.0

* Fixed NNBD issues

## 4.0.0-beta.4

* Logged exception of the db query execution to console
* Added transaction to data insertion
* Fixed SQL column generator to remove size from none character based data type

## 4.0.0-beta.3

* Updated README
* Fixed NNBD issue
* Default database column to `varchar` type
* Default the `varchar` column size to 256

## 4.0.0-beta.2

* Resolved static analysis warnings

## 4.0.0-beta.1

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.0

* Bump to `2.0.0`.

## 2.0.0-beta.1

* Make `reset` reverse migrations.

## 2.0.0-beta.0

* Make `reset` reverse migrations.

## 2.0.0-alpha.5

* Support default values for columns.

## 2.0.0-alpha.4

* Include the names of migration classes when running.

## 2.0.0-alpha.3

* Run migrations in reverse on `rollback`.

## 2.0.0-alpha.2

* Run migrations in reverse on `reset`.

## 2.0.0-alpha.1

* Cast Iterables via `.cast()`, rather than `as`.

## 2.0.0-alpha

* Dart 2 update.

## 1.0.0-alpha+5

`Schema##drop` now has a named `cascade` parameter, of type `bool`.

## 1.0.0-alpha+1

* You can now pass a `connected` parameter.
