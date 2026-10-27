# Angel3 ORM

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/orm/LICENSE)

Runtime support for Angel3 ORM. Includes a clean, database-agnostic query builder and the loading of relations:

* `@HasOne` and `@BelongsTo` are joined, as each record is one row.
* `@HasMany` and `@ManyToMany` are loaded after the records, with one query for all of them, as a join would return a row per item.

See [Loading Relations](https://github.com/dart-backend/angel/tree/master/packages/orm#loading-relations) for details.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_orm: ^10.0.0
```

## Usage

Models are annotated with `@orm`, and `angel3_orm_generator` generates a query class for each, here `EmployeeQuery` of `EmployeeEntity`:

```dart
@serializable
@orm
abstract class EmployeeEntity extends Model {
  String? get firstName;

  String? get lastName;

  double? get salary;
}
```

Run the queries with the executor of a database, such as the `PostgreSqlExecutor` of [`angel3_orm_postgres`](https://pub.dev/packages/angel3_orm_postgres) or the `MySqlExecutor` of [`angel3_orm_mysql`](https://pub.dev/packages/angel3_orm_mysql):

```dart
var query = EmployeeQuery()
  ..where!.firstName.equals('Rich')
  ..orWhere((w) => w.salary.greaterThanOrEqualTo(75000));
List<Employee> employees = await query.get(executor);

var insert = EmployeeQuery();
insert.values
  ..firstName = 'Jane'
  ..salary = 90000;
Optional<Employee> jane = await insert.insert(executor);
```

See [Angel3 ORM](https://github.com/dart-backend/angel/tree/master/packages/orm) for models, relations and columns.

## Supported database

* PostgreSQL version 14 or later
* MariaDB 10.2.x or later
* MySQL 8.x or later

For documentation about the ORM, see [Developer Guide](https://angel3-docs.dukefirehawk.com/guides/orm)

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that need changes in an app:

### Regenerate your models

Upgrade `angel3_orm_generator` to 10.0.0 too, and regenerate the models:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generated queries load relations as described below, and the key of a relation in `QueryValues`, such as `authorId` of a `@BelongsTo AuthorEntity author`, is nullable (`int?`). See the [CHANGELOG of `angel3_orm_generator`](https://pub.dev/packages/angel3_orm_generator/changelog).

### Relations are loaded with a query each

`@HasMany` and `@ManyToMany` are no longer joined. After the records, each is loaded with one query for all of them (`WHERE author_id IN (...)`); `@HasOne` and `@BelongsTo` are still joined. As a record is one row:

* `limit` and `offset` count records, where they counted the rows of the joins, so a record with several items was cut short, or counted more than once.
* `getOne` fetches one row (`LIMIT 1`).
* `get`, `update`, `delete` and `insert` return records with their relations, so `insert` makes a query for each `@HasMany` too.

The query of a `@HasMany` is the one its items are loaded with, so its conditions and order apply to them:

```dart
var query = AuthorQuery();
query.books
  ..where!.published.isTrue
  ..orderBy('title');
```

A relation back to a table that is being loaded is not loaded again, and is left empty. The records of a `@ManyToMany` have their own relations loaded, where they were always empty.

### Inserts on MySQL and MariaDB

An insert's `returningQuery` selects the inserted row by the id given, or by the parameter `@angel3_insert_id` (`insertIdParameter`), instead of the last row by id. A `QueryExecutor` of your own for MySQL or MariaDB must bind that parameter to the driver's insert id, as `angel3_orm_mysql` does. `QueryValues.compileInsertSelect` is deprecated.

### `numeric` and `decimal` columns

`Column.precision` and `Column.scale` are `int?`, and `null` unless given, where they were 17 and 3. On PostgreSQL, a `numeric` or `decimal` without them is unbounded. To keep the columns as they were created, give them:

```dart
@Column(type: ColumnType.decimal, precision: 17, scale: 3)
double? get price;
```
