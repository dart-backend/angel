# Change Log

## 10.0.0

* **Breaking:** `MutableTable.changeColumnType` takes the `length`, `precision` and `scale` of the new type (e.g. `changeColumnType('price', ColumnType.numeric, precision: 10, scale: 2)`). Without a precision or scale, a column changed to `numeric` or `decimal` is unbounded on PostgreSQL, which keeps its values, where it was `numeric(17, 3)`, which rounded them. It also takes the constraints of the column after the change, `isNullable`, `defaultValue` and `autoIncrement`, which are kept as they are when not given, and on PostgreSQL `using`, the expression that converts the values when there is no implicit cast (e.g. `using: 'price::numeric'`). Implementations of `MutableTable` must add these parameters, with `precision`, `scale`, `isNullable`, `defaultValue`, `autoIncrement` and `using` nullable
* fix: `Table.numeric` creates the column with its `precision` and `scale`, which it ignored, and `MigrationColumn` (including `MigrationColumn.from`) keeps a column's precision and scale. Without them, the column is still an unbounded `numeric` on PostgreSQL
* fix: `MigrationColumn.from` keeps all the attributes of a `Column`: its `defaultValue` (so `declareColumn('fee', Column(..., defaultValue: 0))` creates the column with `DEFAULT 0`, which was left out), `name`, `timezone` and `expression`
* fix: A `numeric` or `decimal` column whose precision is below 1, or whose scale is negative or greater than its precision (17 without one), throws an `ArgumentError` when it is declared, instead of failing when the migration is run
* Added `Table.decimal`, as `Table.numeric` for `decimal` columns
* Added `MigrationColumn.precisionArguments`, the `(precision, scale)` of a column's type in SQL, for the runners of each database, which checks them against the database's limits
* `Table.varChar` declares a `MigrationColumn`

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
