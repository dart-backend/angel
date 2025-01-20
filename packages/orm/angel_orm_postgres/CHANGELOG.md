# Change Log

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
