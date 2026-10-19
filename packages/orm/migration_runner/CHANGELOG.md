# Change Log

## 10.0.0

* **Breaking:** `MySqlMigrationRunner` uses [`mysql_dart`](https://pub.dev/packages/mysql_dart) 3, a maintained fork of `mysql_client`, instead of `mysql_client`. It takes the `MySQLConnection` of `mysql_dart`: change `import 'package:mysql_client/mysql_client.dart'` to `import 'package:mysql_dart/mysql_dart.dart'`
* **Breaking:** `MariaDbMigrationRunner` and `MariaDbSchema.run` use `mysql_dart`, instead of [`mysql1`](https://pub.dev/packages/mysql1), which is no longer a dependency. They take the `MySQLConnection` of `mysql_dart`, as those of MySQL do. The two runners share `MySqlFamilyMigrationRunner`, and the two schemas the `run` of `MySqlFamilySchema`
* **Breaking:** The runners no longer use `dart:mirrors`, so they can run in a program compiled with `dart compile exe`. A migration is recorded in the `migrations` table by its `Migration.name` (by default its class name, e.g. `TodoMigration`), where it was the absolute path of its source file and its class name (`/app/lib/todo.dart#TodoMigration`), which changed when the project was moved. The paths written by earlier versions are renamed when the runner starts, so that they are not run again: that of a migration's `legacyPath`, the end of its path (e.g. `lib/migrations/users.dart#UserMigration`), or else that of the only migration of its class name, if no other path has that class name, which is logged as a warning. A path that may be of more than one migration throws a `StateError` rather than be guessed, as the runner cannot tell the source file of a migration. A migration recorded at more than one path of its `legacyPath`, as when the project was moved, keeps only its oldest row. See the README. Two migrations of different classes with the same name throw a `StateError`
* fix: The paths of the `migrations` table are given to the database as parameters, where they were written into the SQL, so that a name with a quote does not break it
* fix: `changeColumnType` on MySQL and MariaDB drops the default of a column that becomes `AUTO_INCREMENT` (a serial type, or `autoIncrement: true`), which the database rejected (`DEFAULT '0' AUTO_INCREMENT`)
* fix: `changeColumnType` to a `TEXT` or `BLOB` type keeps the column's literal default where the server takes one: on MariaDB from 10.2.1, and on MySQL from 8.0.13 as an expression (`DEFAULT ('x')`). Before those, it is dropped, which MySQL rejected with error 1101. A column changed to `JSON` does not keep its default, which is rarely JSON
* fix: `changeColumnType`, `setNotNull` and `dropNotNull` on MySQL and MariaDB keep the column's `COMMENT`, and its `CHARACTER SET` and `COLLATE` when the new type is text, which the `MODIFY` dropped. `nchar` and `nvarchar`, whose character set is the server's, do not keep them. On MariaDB, they also keep the column's `CHECK` constraints, such as the `json_valid` of a `JSON` column, which a `MODIFY` drops, so that invalid JSON could be stored
* fix: The constraints of a column changed on MySQL before 5.7.6 or MariaDB before 10.2.5, which have no `GENERATION_EXPRESSION`, are read without it, where the query failed. A generated column on those servers throws a `StateError`, as its expression cannot be kept. The version of Aurora MySQL (`8.0.mysql_aurora.3.05.2`) is read as that of MySQL 8.0
* fix: A quoted table name with a `.` in it, such as `` `my.table` ``, is not split into a database and a table when the constraints of its columns are read
* `MariaDbIndexes` creates a standard index with `IF NOT EXISTS`, as it does a unique one. The generators, tables and indexes of MySQL and MariaDB share `MySqlFamilyGenerator`, `MySqlFamilyTable` and `MySqlFamilyIndexes`
* **Breaking:** `PostgresMigrationRunner.up` and `MariaDbMigrationRunner.up` throw when a migration fails, as `MySqlMigrationRunner.up` does, and run none of the migrations after it, which may depend on it. They only logged the error, and went on. `MariaDbMigrationRunner` also throws when the `migrations` table cannot be created
* fix: A name shared by two migrations throws before any of them is added, so that none is lost. A `NULL` path of the `migrations` table is skipped, where it failed the PostgreSQL and MariaDB runners, and a path that `mysql1` gives as a `Blob` is read as text
* fix: `MariaDbMigrationRunner` reads a batch number given as text, and that of an empty `migrations` table on `rollback`
* fix: `rollback` undoes the migrations of the last batch newest first, as `reset` does, where it was in the reverse of the order they are given to the runner, so that a migration that another depends on, by a foreign key, was undone first when they were given in another order
* fix: On PostgreSQL, `changeColumnType` to a serial type gives the column the default of the sequence it has, if it lost it (e.g. to `noDefault` before), and a serial type with `autoIncrement: false` is only its integer, as on MySQL and MariaDB
* fix: The `CHECK` constraints kept by a `MODIFY` on MariaDB from 10.5.10 are only those of the column, not one of the table named after it
* fix: The table of `indexes` on MySQL and MariaDB may be qualified by its database (`` `shop`.`orders` ``), which was quoted as one name
* fix: `changeColumnType` to a serial type on MySQL and MariaDB makes the column `AUTO_INCREMENT` only if it is a key, as a `CREATE TABLE` does only its primary key, which the database rejected for another column. It keeps a column `INVISIBLE`, and drops the `json_valid` `CHECK` of a MariaDB `JSON` column changed to another type
* fix: The table and column of a `REFERENCES` on MySQL and MariaDB are quoted (`` REFERENCES `order`(`id`) ``), so that they may be reserved words
* Removed `ModifyingAlterTable.modifications`, which nothing used
* **Breaking:** Two migrations of the same name throw a `StateError`, as do two of a class that takes arguments without their own `name`, such as `TableMigration('users')` and `TableMigration('posts')`, of which the second was skipped. One added again, whose `up` makes the same changes, is still skipped, with a warning
* **Breaking:** The tables of `create`, `drop`, `alter` and `rename` on MySQL and MariaDB are quoted, each part of a qualified name in backticks (`` CREATE TABLE `order` ``), so that they may be reserved words; a name already in backticks is quoted once
* **Breaking:** A default that is not a `String`, a number, a `bool` or `RawSql` is a string literal of its `toString()`, where it was written as it is. A `DateTime` is a literal of its date and time (`'2020-01-02 03:04:05.000'`), which was invalid SQL; on PostgreSQL, a UTC one has its offset (`'2020-01-01 00:00:00.000+00'`), so that a `timestamp with time zone` is not read in the time zone of the session. Give SQL as `RawSql`
* fix: The columns of an index on MySQL, MariaDB and PostgreSQL are quoted only if they are names, so that a prefix (`body(100)`), an expression (`lower(email)`) or an order (`email DESC`) may be given, which was quoted as a name. A name in backticks or double quotes is quoted for the database, as MySQL reads one in double quotes as a string
* fix: `PostgresMigrationRunner` runs a migration and records it in the `migrations` table, or undoes it and removes it, in one transaction, so that one cut off between them is neither run nor recorded, and run again
* fix: `rollback` and `reset` undo a migration recorded more than once once, where its `down` was run again, and failed
* fix: On PostgreSQL, `changeColumnType` of an identity column to a serial type does not give it a default, which PostgreSQL rejected
* The runners extend `SqlMigrationRunner<S>`, which runs, records and undoes the migrations with what each database gives: how its `migrations` table is created and queried, its schema `S`, and how a schema is run and recorded (`runAndRecord`), or run and removed (`runAndRemove`)
* `PostgresSchema.run` takes a `Session`, such as a transaction, in which it runs, as well as a `Connection`, in a transaction of its own
* Deprecated the `connected` parameter of the runners, which is not used
* fix: The class name of a path written by an earlier version is matched with that of a generic migration without its type arguments (`SeedMigration`, of `SeedMigration<User>`), so that it is not run again
* fix: A server without `GENERATION_EXPRESSION` is told by MySQL's error 1054 only: by the code of the exception of `mysql1` or `mysql_client`, or of one wrapped by a caller by its code in the message (`Error 1054 (`, `[1054]`), whatever its language, and not by another error, such as of the syntax, that quotes the query
* **Breaking:** The tables of PostgreSQL may be qualified by their schema (`audit.events` is `"audit"."events"`), where the whole name was quoted as one, and a name already in double quotes is quoted once. A name with a `.` that is one table, such as `app.v1_users` of an earlier version, which is now the table `v1_users` of the schema `app`, is given in double quotes (`'"app.v1_users"'`). A table renamed stays in its schema: `rename` takes a name qualified by that schema only, and throws an `ArgumentError` for another (a table not qualified, whose schema is not known, is renamed to the own name given, and stays in its schema), as `RENAME TO` does not move a table to another schema (use `SET SCHEMA`). The sequence of a serial column, an index dropped (unless its name is qualified) and the primary key constraint of a table are of its schema, and named after the table's own name (`"events_pkey"`, where it was `"audit.events_pkey"`), and a column given in double quotes (`'"Id"'`) is known by its own name
* fix: `runMigrations` closes the runner when a migration fails, which now throws, as well as when it succeeds, so that the connection is not left open
* fix: On PostgreSQL, `changeColumnType` to a serial type with `defaultValue: noDefault` gives the column no default from a sequence, which was given again
* fix: A `double` default that is not finite is `'NaN'`, `'Infinity'` or `'-Infinity'` on PostgreSQL, and throws an `ArgumentError` on MySQL and MariaDB, which have none, where it was invalid SQL
* fix: A PostgreSQL alter table, and its indexes, may be compiled again, as those of MySQL and MariaDB
* fix: A name, as of a table or of a column of an index, is unquoted once when it is quoted for PostgreSQL, MySQL and MariaDB, so that a name whose quotes are its own keeps them. A table of MySQL and MariaDB may still be given in double quotes, as before; a column is unquoted of backticks only, which MySQL reads as a name, where its constraints are read as in the `MODIFY`
* fix: `addIndex` of a standard index in a PostgreSQL alter table creates it, with a `CREATE INDEX IF NOT EXISTS` after the clauses before it, where it was left out, and the migration was recorded as run, and its `dropIndex` drops it, or a unique constraint, whichever the index is, and raises an error if the table has neither, as of a typo, so that the migration is not recorded as run. A unique index of an expression or with an order, which a constraint cannot be of, is a `CREATE UNIQUE INDEX`, where the constraint was invalid SQL. A primary key of an expression, a prefix or an order throws an `ArgumentError` on every database. A column declared with a standard index (`indexType: IndexType.standardIndex`) in a PostgreSQL create or alter table has its index, `<table>_<column>_idx`, which was left out
* fix: On PostgreSQL, a column added in an alter table in double quotes (`'"Id"'`) is that of a clause of it without them (`'Id'`), which runs in another statement
* fix: The block that gives a column changed to a serial type its sequence on PostgreSQL takes a table or column whose name has a `'` or a `$$`, which ended it
* fix: A migration not recorded, whose `legacyPath` is of no path of the `migrations` table, which has one of its class name, throws a `StateError`, as of a typo, where it was run again, or its path taken to be of another migration of the class name
* fix: A `legacyPath` is matched with the paths of its case first, as on Linux, where `Users.dart` and `users.dart` are two files, and of either case only if none is of its case, as on Windows, where they were both of the path, which threw
* fix: A path of the `migrations` table is one of an earlier version only if it ends with `.dart#<class name>`, so that a `name` with a `#`, such as `users#v2`, is not renamed or deleted as one
* fix: `runMigrations` throws the error of a migration that fails, rather than one of closing the runner, which is logged
* fix: `MariaDbSchema.run` runs the statements of the schema one by one, as `mysql1` does not enable more than one statement in a query, so that a migration of more than one statement, such as a table and its indexes, failed
* **Breaking:** A column whose type has a precision (`numeric`, `decimal`) is created with its precision and scale, e.g. `numeric(10, 2)`. They were left out, so MySQL/MariaDB created `DECIMAL(10,0)` and rounded values to whole numbers (1234.56 was stored as 1235). A column without them is `numeric(17, 3)` on MySQL and MariaDB, and still an unbounded `numeric` on PostgreSQL. A precision or scale above the database's limits (65 and 30 on MySQL, 65 and 38 on MariaDB, a precision of 1000 on PostgreSQL) throws an `ArgumentError` when the SQL is built, instead of an error from the database
* **Breaking:** `changeColumnType` of the PostgreSQL, MySQL and MariaDB alter tables takes the `precision` and `scale` of the new type, as `MutableTable` now requires (e.g. `ALTER COLUMN "price" TYPE numeric(10, 2)`); it always used `numeric(17, 3)`, which rounded the values of a column changed to it. Without them, it is an unbounded `numeric` on PostgreSQL and `numeric(17, 3)` on MySQL and MariaDB. Its default `length` is `Column.defaultLength` (255) for MySQL and MariaDB too, where it was 256
* **Breaking:** **Security** String defaults are quoted and escaped the same way on every database, by doubling each single quote (and on MySQL and MariaDB each backslash). MariaDB wrote them without quotes (`DEFAULT active`), MySQL quoted only `varchar` defaults, and PostgreSQL escaped a quote as `'`, which it does not read as an escape, so a default such as `O'Brien` broke the SQL and a crafted default could inject SQL. `RawSql` defaults are still written as they are. A `String` default is now always a string literal, so a migration that gave SQL as a `String` must give it as `RawSql`: `defaultsTo('CURRENT_TIMESTAMP')` is now `DEFAULT 'CURRENT_TIMESTAMP'`, which the database rejects for a date, so use `defaultsTo(RawSql('CURRENT_TIMESTAMP'))`; and a default quoted by the migration for MariaDB, such as `defaultsTo("'active'")`, is now stored with its quotes, so use `defaultsTo('active')`
* fix: `changeColumnType` keeps the constraints of the column that are not given, and sets those given (`isNullable`, `defaultValue` and, on MySQL and MariaDB, `autoIncrement`). MySQL and MariaDB define the whole column again in `MODIFY`, which dropped its `NOT NULL`, `DEFAULT`, `AUTO_INCREMENT` and `ON UPDATE`; the schema now reads them from `information_schema` when it is run, and gives them again (e.g. ``MODIFY `fee` decimal(10, 2) NOT NULL DEFAULT 0``). `compile()` without the database has only the constraints given. PostgreSQL keeps the constraints of the column, and sets those given (`SET NOT NULL`, `DROP NOT NULL`, `SET DEFAULT`)
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
* fix: A MySQL or MariaDB alter table is more than one `ALTER TABLE` statement where a clause is of a column renamed or added before it, which starts another, as MySQL and MariaDB know a column of a statement by its name before it (e.g. `renameColumn('b', 'c')` and then `changeColumnType('c', ...)`, or `varChar('e')` and then `setNotNull('e')`, which failed). The constraints of the columns a statement changes are read once those before it have run, and the columns added are in the order they are declared
* fix: A `renameColumn` or `dropColumn` of a MySQL or MariaDB alter table of a column changed before in it (`changeColumnType`, `setNotNull`, `dropNotNull`) starts another statement too, as the statement knows the column by its name before the change, which failed
* fix: A column added by a MySQL or MariaDB alter table has its index (`.unique()` or a standard index), as in a `CREATE TABLE`, which was left out
* fix: The columns added by a PostgreSQL alter table are in the order they are declared, and a clause of a column added before it in its statement starts another (e.g. `integer('x')` and then `changeColumnType('x', ...)`, which failed, as the `ADD COLUMN` was last)
* fix: The `dropPrimaryIndex` of PostgreSQL `indexes` ends its statement, which ran into the next one
* fix: The changes of a column in a statement of a MySQL or MariaDB alter table (`changeColumnType`, `setNotNull`, `dropNotNull`) are one `MODIFY`, with the constraints given last and the type given last, as MySQL and MariaDB take one `MODIFY` of a column in a statement, which failed
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
