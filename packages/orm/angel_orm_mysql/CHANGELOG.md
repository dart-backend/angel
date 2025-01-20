# Change Log

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
