# Change Log

## 10.0.3

### Breaking changes in 10.0.3

* **Breaking:** `groupBy`, `crossJoin`, `join`, `leftJoin`, `rightJoin`, `fullOuterJoin` and `selfJoin` throw an `ArgumentError` for a name that is not an identifier, which may be quoted (`"order"`, `` `order` ``) and qualified (`table.column`), as `orderBy` does when compiled, where it was written into the SQL as given, so a value from a request could add SQL to a query. This covers table names, keys, aliases and `additionalFields`; `groupBy` also accepts several columns separated by commas. An expression, or SQL given as a table name, is no longer accepted, nor a backslash or a quote of its own kind in a quoted name: join a `Query` in place of a subquery
* **Breaking:** The `op` of a join must be one of `=`, `!=`, `<>`, `<`, `<=`, `>` and `>=`

### New in 10.0.3

* **Queries:** `orderBy` accepts a quoted name, as a reserved word must be

### Fixes in 10.0.3

* **Queries:** A query with no `fields` keeps its joins, which were dropped without an error, so an `INNER JOIN` filtered nothing. It selects `table.*`, only the columns of its own table
* **Queries:** `isIn` and `isNotIn` of a number, an enum or a string with no values are `FALSE` and `TRUE`, where they were `IN ()`, which is not valid SQL
* **Queries:** A self join is an `INNER JOIN` of the table by an alias, where it was `SELF JOIN`, which is not valid SQL
* **Queries:** A date predicate set directly is joined with `AND` to those of its parts (`year`, `month`, ...), which it discarded
* **Queries:** An expression column is valid SQL in `getByKeys`, and is left out of a `RETURNING`, where it may name a join that is not in scope, as the select around it computes it
* **Updates:** The rows of a `limit` are the first in the order of `orderBy`, which was ignored, so that other rows could be updated
* **Updates:** An update on MySQL of a table without an id throws a `StateError` for an `offset`, which it cannot apply, where it was a syntax error
* **Updates:** `compileForUpdate` leaves the values it is given as they are, is empty where it was a bare `SET` with only a null `created_at`, and throws an `ArgumentError` for a key that is not a plain column name, as a key of `MapQueryValues` was written into the SQL as given
* **Deletes:** A `limit` and an `offset` apply, in the order of `orderBy`, where they were a syntax error on PostgreSQL, and on MySQL with both. An `orderBy` without a `limit` orders the rows returned
* **Deletes:** A `groupBy` throws a `StateError` where it was a syntax error, as does an `offset` on MySQL of a table without an id
* **Inserts:** An insert ignores the conditions, `limit` and `offset` of its query, where its row was filtered out on PostgreSQL, and its row was not selected on MySQL
* **JSON:** A property `asInt` or `asDouble` is compared as a number, where `greaterThan` compared text, so that `10` was less than `5`, and `isBetween` and `isIn` were an error. A property that is no number matches no comparison
* **JSON:** A property `asDateTime` is compared as a date, with a parameter of a valid name and the table name of the query, where its parameter was invalid
* **JSON:** A property `asMap` or `asList` has predicates of its own, where they named the column twice, and `isIn` of a property `asString` has a parameter of a valid name
* **JSON:** A `'` in the key of a property is escaped, where it was written into the SQL as given, so a key from a request could add SQL to a query
* **Unions:** `get` and `getOne` load the relations of the rows with those of the left query, as `Query` does; `parseRows` of a `QueryBase` gives them. A value's name that is renamed is not replaced in a string literal or a quoted identifier
* **Values:** `mapToBool` reads the strings `f` and `false`, in any case, as false
* **Values:** `defaultDate`, and the `mapToDateTime` of a null, is 1970-01-01 in UTC as documented, where it was in the local time zone

## 10.0.2

### New in 10.0.2

* **Logging:** `debugMode`, whether assertions are enabled, and `logValues`, which logs the values of a query in debug mode only, for executors to log as `Query` does

### Fixes in 10.0.2

* **Logging:** The values of a query, which may be passwords or personal data, are logged in debug mode only, with assertions enabled (as with `dart test` or `dart run --enable-asserts`), where they were logged at `FINE` whenever it was logged; those of an insert without an id and of an update on MySQL are logged too. Log messages are built only when `FINE` is logged
* **Executors:** An insert or a delete on PostgreSQL no longer gives the executor `returningFields`, as its SQL has its `RETURNING` already, in a `WITH` clause: an executor that added one, as `PostgreSqlPoolExecutor` of `angel3_orm_postgres` 10.0.1 does, failed with a syntax error. `QueryExecutor.query` documents that its query is complete

## 10.0.1

### Breaking changes in 10.0.1

* **Breaking:** A `DateTime` in a `where` clause with its time, such as of `lessThan`, `equals`, `isBetween` or `isIn`, is bound as a parameter, so the executor sends it as it stores a `DateTime`, where it was written into the SQL as its wall-clock time, whatever its time zone. A local `DateTime` now matches the rows written with it on PostgreSQL and with `MariaDbExecutor`, which store a `DateTime` as UTC, and no longer matches rows they stored as local time before. A `QueryExecutor` of your own must accept a `DateTime` parameter

### Fixes in 10.0.1

* **Queries:** A `DateTime` comparison without its time (`includeTime: false`) compares the date of the `DateTime` as given, as before
* **Queries:** `isIn` and `isNotIn` of a `DateTime` column with no values are `FALSE` and `TRUE`, where they were `IN ()`, which is not valid SQL
* **Queries:** A `Union` gives the right query's values names of their own where both queries use one, where the right query used the left one's value. It takes the values of its queries when it is compiled, so it also has those given after it was made

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `get`, `update`, `delete` and `insert` return records with the relations `loadRelations` loads, each with a query of its own after the records: a record is one row, so a `limit` or `offset` counts records, and `getOne` fetches one row
* **Breaking:** On MySQL and MariaDB, an insert's `returningQuery` selects the inserted row by the id given, or by `@angel3_insert_id` (`insertIdParameter`), which the executor binds to the driver's insert id, instead of the last row by id, which may be another connection's
* **Breaking:** `Column.precision` and `Column.scale` are `int?`, and `null` unless given (were 17 and 3). A `numeric` or `decimal` without them is unbounded on PostgreSQL

### New in 10.0.0

* `replacePlaceholders`, which swaps `@name` placeholders for a driver's (e.g. `?`)
* `QueryValues.parameterNameOf`, and `Column.defaultLength`, `defaultPrecision` and `defaultScale`
* `Query.loadRelations`, which loads the relations of records that are not joined, such as a has-many, with a query each for all the records, and `loadsRelations`, `getByKeys`, `pivotKeys`, `valueOf` and `joinedRow` for it; `JoinBuilder.query` and `JoinBuilder.columnNameFor`

### Fixes in 10.0.0

* **Joins:** A query selects the columns of the joins of a query it joins, so a relation of a relation, such as a `@HasMany` nested in a `@HasMany`, is no longer dropped; a join that cannot be compiled selects `NULL`s named as its columns, including those of its own joins, so the columns after it keep their place
* **Security:** `StringSqlExpressionBuilder.like` passes its pattern as a parameter, where a pattern from user input allowed SQL injection; `sanitize` is applied to the pattern
* **Parameters:** `Query.reserveName` never returns the same name twice, so two values of one column no longer overwrite each other (an `update` with a condition and a new value on one column changed the wrong rows). `replacePlaceholders` leaves `@` in string literals, quoted identifiers and `@@variables`
* **MySQL and MariaDB:** An insert into a table without an id returns the values it inserted; `update` and `delete` select their rows first, in a transaction, and return them. `QueryValues.compileInsertSelect` is deprecated
* **`update()`:** Returns the rows it updated even when their new values no longer match its conditions, and supports `limit()` and `offset()` on PostgreSQL
* **Conditions:** `notWhere` is joined with `AND NOT`, a `WHERE` no longer starts with `AND`/`OR`, and nested and JSON conditions are joined and qualified correctly. Date parts use `EXTRACT`; `DateTime` `isIn`/`isNotIn` quote the dates; a `double` is written as a plain number
* **Values:** `mapToDouble` and `mapToInt` convert numbers of the other type, `BigInt`s and numeric strings, and throw `FormatException` for a value that cannot be converted
* **`getOne`:** Fetches one row (`LIMIT 1`) when the query has no joins and no limit of its own
* **Docs:** The README tells how to install and use the package, and how to migrate from 9.x


## 9.1.1

* Fix analyzer warnings and errors

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.4.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.3.2

* Updated `intl` to 0.20.0

## 8.3.1

* Added support for string to bool conversion in the query results

## 8.3.0

* Set `createdAt` and `updatedAt` default to CURRENT_TIMESTAMP

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

## 7.0.1

* Reduced debugging verbosity

## 7.0.0

* Require Dart >= 2.17

## 6.1.0

* Fixed issue #68: Support for non-nullable type
* Added `defaultValue` to `@Column` annotation

## 6.0.1

* Added `mapToDateTime`

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Added `MySQLDialect` to handle MySQL database specific features
* Updated `insert` and `update` query to support database without writable CTE

## 4.0.6

* Fixed multiple `orderBy` error

## 4.0.5

* Added `where.raw()`
* Added `select(List fields)`

## 4.0.4

* Changed default varchar size to 255
* Changed default primary key to serial
  
## 4.0.3

* Removed debugging messages

## 4.0.2

* Updated linter to `package:lints`
* Set `createdAt` and `updatedAt` to current datetime as default

## 4.0.1

* Fixed expressions parsing error
* Fixed json data type error
* Added debug logging to sql query execution

## 4.0.0

* Updated `Optional` package

## 4.0.0-beta.4

* Added `hasSize` to `ColumnType`

## 4.0.0-beta.3

* Updated README
* Fixed NNBD issues

## 4.0.0-beta.2

* Fixed static analysis warning

## 4.0.0-beta.1

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.1.0-beta.3

* Remove parentheses from `AS` when renaming raw `expressions`.

## 2.1.0-beta.2

* Add `expressions` to `Query`, to support custom SQL expressions that are
read as normal fields.

## 2.1.0-beta.1

* Calls to `leftJoin`, etc. alias all fields in a child query, to prevent
`ambiguous column a0.id` errors.

## 2.1.0-beta

* Split the formerly 600+ line `src/query.dart` up into
separate files.
* **BREAKING**: Add a required `QueryExecutor` argument to `transaction`
callbacks.
* Make `JoinBuilder` take `to` as a `String Function()`. This will allow
ORM queries to reference their joined subqueries.
* Removed deprecated `Join`, `toSql`, `sanitizeExpression`, `isAscii`.
* Always put `ORDER BY` before `LIMIT`.
* `and`, `or`, `not` in `QueryWhere` include parentheses.
* Add `joinType` to `Relationship` class.

## 2.0.2

* Place `LIMIT` and `OFFSET` after `ORDER BY`.

## 2.0.1

* Apply `package:pedantic` fixes.
* `@PrimaryKey()` no longer defaults to `serial`, allowing its type to be
inferenced.

## 2.0.0

* Add `isNull`, `isNotNull` getters to builders.

## 2.0.0-dev.24

* Fix a bug that caused syntax errors on `ORDER BY`.
* Add `pattern` to `like` on string builder. `sanitize` is optional.
* Add `RawSql`.

## 2.0.0-dev.23

* Add `@ManyToMany` annotation, which builds many-to-many relations.

## 2.0.0-dev.22

* `compileInsert` will explicitly never emit a key not belonging to the
associated query.

## 2.0.0-dev.21

* Add tableName to query

## 2.0.0-dev.20

* Join updates.

## 2.0.0-dev.19

* Implement cast-based `double` support.
* Finish `ListSqlExpressionBuilder`.

## 2.0.0-dev.18

* Add `ListSqlExpressionBuilder` (still in development).

## 2.0.0-dev.17

* Add `EnumSqlExpressionBuilder`.

## 2.0.0-dev.16

* Add `MapSqlExpressionBuilder` for JSON/JSONB support.

## 2.0.0-dev.15

* Remove `Column.defaultValue`.
* Deprecate `toSql` and `sanitizeExpression`.
* Refactor builders so that strings are passed through

## 2.0.0-dev.14

* Remove obsolete `@belongsToMany`.

## 2.0.0-dev.13

* Push for consistency with orm_gen @ `2.0.0-dev`.

## 2.0.0-dev.12

* Always apply `toSql` escapes.

## 2.0.0-dev.11

* Remove `limit(1)` except on `getOne`

## 2.0.0-dev.10

* Add `withFields` to `compile()`

## 2.0.0-dev.9

* Permanent preamble fix

## 2.0.0-dev.8

* Escapes

## 2.0.0-dev.7

* Update `toSql`
* Add `isTrue` and `isFalse`

## 2.0.0-dev.6

* Add `delete`, `insert` and `update` methods to `Query`.

## 2.0.0-dev.4

* Add more querying methods.
* Add preamble to `Query.compile`.

## 2.0.0-dev.3

* Brought back old-style query builder.
* Strong-mode updates, revised `Join`.

## 2.0.0-dev.2

* Renamed `ORM` to `Orm`.
* `Orm` now requires a database type.

## 2.0.0-dev.1

* Restored all old PostgreSQL-specific annotations. Rather than a smart runtime,
having a codegen capable of building ORM's for multiple databases can potentially
provide a very fast ORM for everyone.

## 2.0.0-dev

* Removed PostgreSQL-specific functionality, so that the ORM can ultimately
target all services.
* Created a better `Join` model.
* Created a far better `Query` model.
* Removed `lib/server.dart`

## 1.0.0-alpha+10

* Split into `angel_orm.dart` and `server.dart`. Prevents DDC failures.

## 1.0.0-alpha+7

* Added a `@belongsToMany` annotation class.
* Resolved [##20](https://github.com/angel-dart/orm/issues/20). The
`PostgreSQLConnectionPool` keeps track of which connections have been opened now.

## 1.0.0-alpha+6

* `DateTimeSqlExpressionBuilder` will no longer automatically
insert quotation marks around names.

## 1.0.0-alpha+5

* Corrected a typo that was causing the aforementioned test failures.
`==` becomes `=`.

## 1.0.0-alpha+4

* Added a null-check in `lib/src/query.dart##L24` to (hopefully) prevent it from
crashing on Travis.

## 1.0.0-alpha+3

* Added `isIn`, `isNotIn`, `isBetween`, `isNotBetween` to `SqlExpressionBuilder` and its
subclasses.
* Added a dependency on `package:meta`.
