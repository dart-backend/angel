# Change Log

## 10.0.0

* **Breaking:** A column whose type has a precision (`numeric`, `decimal`) is created with its precision and scale, e.g. `numeric(10, 2)`. They were left out, so MySQL/MariaDB created `DECIMAL(10,0)` and rounded values to whole numbers (1234.56 was stored as 1235). A column without them is `numeric(17, 3)` on MySQL and MariaDB, and still an unbounded `numeric` on PostgreSQL. A precision or scale above the database's limits (65 and 30 on MySQL, 65 and 38 on MariaDB, a precision of 1000 on PostgreSQL) throws an `ArgumentError` when the SQL is built, instead of an error from the database
* **Breaking:** `changeColumnType` of the PostgreSQL, MySQL and MariaDB alter tables takes the `precision` and `scale` of the new type, as `MutableTable` now requires (e.g. `ALTER COLUMN "price" TYPE numeric(10, 2)`); it always used `numeric(17, 3)`, which rounded the values of a column changed to it. Without them, it is an unbounded `numeric` on PostgreSQL and `numeric(17, 3)` on MySQL and MariaDB. Its default `length` is `Column.defaultLength` (255) for MySQL and MariaDB too, where it was 256
* **Breaking:** **Security** String defaults are quoted and escaped the same way on every database, by doubling each single quote (and on MySQL and MariaDB each backslash). MariaDB wrote them without quotes (`DEFAULT active`), MySQL quoted only `varchar` defaults, and PostgreSQL escaped a quote as `'`, which it does not read as an escape, so a default such as `O'Brien` broke the SQL and a crafted default could inject SQL. `RawSql` defaults are still written as they are. A `String` default is now always a string literal, so a migration that gave SQL as a `String` must give it as `RawSql`: `defaultsTo('CURRENT_TIMESTAMP')` is now `DEFAULT 'CURRENT_TIMESTAMP'`, which the database rejects for a date, so use `defaultsTo(RawSql('CURRENT_TIMESTAMP'))`; and a default quoted by the migration for MariaDB, such as `defaultsTo("'active'")`, is now stored with its quotes, so use `defaultsTo('active')`
* fix: `changeColumnType` keeps the constraints of the column that are not given, and sets those given (`isNullable`, `defaultValue` and, on MySQL and MariaDB, `autoIncrement`). MySQL and MariaDB define the whole column again in `MODIFY`, which dropped its `NOT NULL`, `DEFAULT`, `AUTO_INCREMENT` and `ON UPDATE`; the schema now reads them from `information_schema` when it is run, and gives them again (e.g. ``MODIFY `fee` decimal(10, 2) NOT NULL DEFAULT 0``). Others, such as `COMMENT` or `COLLATE`, are still not kept. `compile()` without the database has only the constraints given. PostgreSQL keeps the constraints of the column, and sets those given (`SET NOT NULL`, `DROP NOT NULL`, `SET DEFAULT`)
* **Breaking:** `MySqlSchema.run` throws when the SQL fails, as `MariaDbSchema.run` does, so that the runner does not record a failed migration as run. It only logged the error
* fix: On MySQL and MariaDB, the statements of a schema before an alter table that changes a column's type are run before the column's constraints are read, so that a table created earlier in the migration has its constraints kept, and `compile()` may be called before `run()`. A table qualified by its database (`` `shop`.`orders` ``) is read from that database, in one query for all the columns changed of a table, and a column that is not found throws a `StateError`, as the `MODIFY` would drop its constraints. A column of a date and time type is always read, so that it keeps its `ON UPDATE`, which `changeColumnType` cannot be given, when the other constraints are
* fix: `changeColumnType` on MySQL and MariaDB keeps the column's `AUTO_INCREMENT` only for an integer type, and its `ON UPDATE` and default of the current time only for a date and time type, which the database rejected for the others (e.g. `` MODIFY `id` decimal(17, 3) AUTO_INCREMENT ``). An `autoIncrement` given is still set
* fix: The default of the current time of a column is read as SQL from MySQL before 8.0.13 and MariaDB before 10.2.7, which have no `DEFAULT_GENERATED`, and the default of a `bit` (`b'1'`) on both, which were written as strings (`DEFAULT 'CURRENT_TIMESTAMP'`). MariaDB before 10.2.7 gives its other defaults as values, as MySQL does
* fix: `MySqlSchema.run` runs the statements of the schema one by one. `mysql_client` reads the result of only the first statement of a query, so a migration of more than one statement, such as a table and its indexes, was not run, and the results of the next queries were those of its other statements. A `;` in a string, a quoted identifier or a comment does not end a statement
* fix: `PostgresSchema.run` runs the SQL with the simple query protocol, as the extended one rejects more than one statement, so that a migration of more than one statement, such as a table and its indexes, failed
* fix: A `numeric` or `decimal` column with a precision but no scale has a scale of 3 (or its precision, if smaller), e.g. `numeric(10, 3)`, where `numeric(10)` had a scale of 0 and rounded values to whole numbers. Give `scale: 0` for that
* fix: The changes and the columns added of a MySQL, MariaDB or PostgreSQL alter table are compiled as one statement, which was ended twice (`;\n;`), so that a schema with an alter table followed by another statement failed
* `changeColumnType` with a `defaultValue` of `noDefault` removes the column's default, which MySQL and MariaDB otherwise keep, so that a column whose default the new type cannot have (e.g. `'n/a'` of an `int`) can be changed. `RawSql('NULL')` failed for a `NOT NULL` column
* fix: `renameColumn` of MariaDB writes the new name as MySQL does (`RENAME COLUMN a TO b`), where it was in double quotes, which MariaDB reads as a string
* fix: `changeColumnType` on MySQL and MariaDB keeps the `UNSIGNED` of a column changed to a numeric type, and the expression of a generated column, `STORED` or `VIRTUAL`, which the `MODIFY` dropped (an `int unsigned` referenced by a foreign key became a signed `bigint`, and a generated column a plain one). As these cannot be given, the constraints of a changed column are always read from the database
* fix: The changes of a column in a MySQL or MariaDB alter table (`changeColumnType`, `setNotNull`, `dropNotNull`) are one `MODIFY`, with the constraints given last and the type given last, as MySQL and MariaDB take one `MODIFY` of a column in a statement, which failed
* fix: The columns of a PostgreSQL index are quoted (`addIndex` of an alter table and of `indexes`), so that they may be reserved words or have capitals. A `dropColumn` of PostgreSQL is a statement of its own, and a column changed to a serial type and then dropped is given no sequence, which failed
* fix: `setNotNull` and `dropNotNull` of MySQL and MariaDB define the column again with a `MODIFY`, which keeps its type as `information_schema` gives it (e.g. `int(10) unsigned`) and its other constraints, as they have no `ALTER COLUMN ... SET NOT NULL`, which failed
* fix: `smallSerial` and `bigSerial` are `smallint` and `bigint` on MySQL and MariaDB, as `serial` is `int`, which they do not have. A column changed to a serial type gets `AUTO_INCREMENT`, unless `autoIncrement: false` is given, and a serial primary key of any size is `AUTO_INCREMENT`
* fix: The `renameColumn` and `rename` of a PostgreSQL alter table are statements of their own, as PostgreSQL takes them with no other clause, so that a rename with other changes failed. The changes after a `rename` are of the new name, and a column changed to a serial type gets its sequence by the names after the renames
* fix: The columns of MySQL and MariaDB are quoted in every clause (`CREATE TABLE`, `ADD`, `DROP`, `RENAME COLUMN` and indexes), as in `MODIFY`, so that they may be reserved words such as `order`. A column given already in backticks is quoted once
* fix: `reset` undoes the newest migrations first, by batch and then by the order they were run in, as a migration may depend on those before it. It undid the oldest first, which failed for a table referenced by a later one
* fix: PostgreSQL identifiers double the quotes in them (`"a""b"`) in every statement
* The precision and scale of `changeColumnType`, and of a column added by an alter table, are checked against the database's limits when they are declared, so that the schema is compiled once when it is run. The alter tables and schemas of MySQL and MariaDB share their code, but for their clients and the `IF EXISTS` of MariaDB's indexes
* Added `using` to `changeColumnType`, an expression that converts the values on PostgreSQL (`ALTER COLUMN "price" TYPE numeric(10, 2) USING price::numeric`), as a change between types without an implicit cast, such as from `text` to `numeric`, failed. MySQL and MariaDB convert the values themselves
* fix: `changeColumnType` on PostgreSQL changes a column to the integer of a serial type (`int` for `serial`, `bigint` for `bigserial`, `smallint` for `smallserial`), which are not types a column can be changed to. A column changed to a serial type, or with `autoIncrement: true`, that has no sequence is given one as `serial` does: a sequence owned by the column, which starts after its greatest value, as its default. A sequence it has, of a smaller integer, is changed to that of the new type, so that a `serial` changed to `bigserial` goes on after 2147483647; one of a greater integer is kept. It also drops the old default before changing the type when a new `defaultValue` is given, as the old one may not be cast to the new type
* fix: The column of a MySQL or MariaDB `MODIFY` is quoted (`` MODIFY `order` int ``), so that it may be a reserved word; a column given already in backticks (`` '`order`' ``), as migrations did for a reserved word, is quoted once
* fix: The expression default of a column on MySQL 8, which `information_schema` gives with its quotes escaped (`concat(_utf8mb4'a')`), is kept as SQL (`(concat(_utf8mb4'a'))`), which failed
* Removed the unused dependency on `charcode`
* test: `precision_test.dart` checks the SQL for numeric and decimal columns, and creates and alters them on PostgreSQL and MariaDB
* test: The tests on a database are skipped, with the reason, when it cannot be reached at `POSTGRES_HOST` or `MYSQL_HOST`, and the test files are run one at a time (`dart_test.yaml`), as they share the tables of `orm_test`

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
