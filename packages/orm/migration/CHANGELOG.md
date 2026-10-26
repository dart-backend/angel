# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Added `Migration.name`, which identifies a migration in the `migrations` table (default: its class name); override it to survive a rename or `--obfuscate`. A class that `implements Migration` must add it
* **Breaking:** `MutableTable.changeColumnType` takes `length`, `precision` and `scale`, the column's constraints after the change (`isNullable`, `defaultValue`, `autoIncrement`, kept when not given), and on PostgreSQL `using`. Without a precision, a `numeric` or `decimal` is unbounded on PostgreSQL, where it was `numeric(17, 3)`, which rounded values. Implementations must add these parameters

### New in 10.0.0

* `Migration.legacyPath`, so a runner can rename a migration recorded by an earlier version
* `noDefault`, to remove a column's default in `changeColumnType`
* `Table.decimal`, and `MigrationColumn.precisionArguments` for the runners

### Fixes in 10.0.0

* **Precision:** `Table.numeric` and `MigrationColumn` keep a column's precision and scale; an invalid precision or scale throws when the column is declared
* **`MigrationColumn.from`:** Keeps every attribute of a `Column`, including its `defaultValue`

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.5.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.4.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.3.0

* Added `addIndex`, `dropIndex` and `dropPrimaryIndex`

## 8.2.1

* Updated README

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

## 7.1.0

* Require Dart >= 2.18

## 7.0.0

* Require Dart >= 2.17

## 6.1.0

* Updated temporal fields

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.4

* Updated README
* Removed deprecated

## 4.0.3

* Updated README

## 4.0.2

* Updated default varchar column size to 255
  
## 4.0.1

* Updated linter to `package:lints`

## 4.0.0

* Fixed NNBD

## 4.0.0-beta.3

* Updated README
* Fixed NNBD

## 4.0.0-beta.2

* Resolved static analysis warnings

## 4.0.0-beta.1

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.0

* Bump to `2.0.0`.

## 2.0.0-rc.0

* Make abstract `Schema.alter` use `MutableTable`.

## 2.0.0-alpha.1

* Changes to work with `package:angel_orm@2.0.0-dev.15`.

## 2.0.0-alpha

Dart 2 update.
