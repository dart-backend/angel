# Change Log

## 6.1.0

* Upgraded to `lints` 2.x.x
* Fixed issue #70. Incorrectly generated SQL for `defaultsTo('Default Value')`
* Mapped timestamp to datetime for MySQL and MariaDB
* Fixed `MariaDbMigrationRunner` to work with MariaDB
* Fixed `MySqlMigrationRunner` to work with MySQL and MariaDB

## 6.0.1

* Added `MariaDbMigrationRunner` to support MariaDB migration with `mysql1` driver
* Updated `MySqlMigrationRunner` to support MySQL migration with `mysql_client` driver

## 6.0.0

* Updated to SDK 2.16.x
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

* Migrated to support Dart SDK 2.12.x NNBD

## 3.0.0

* Migrated to work with Dart SDK 2.12.x Non NNBD

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
