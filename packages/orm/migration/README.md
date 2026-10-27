# Angel3 Migration

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_migration?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/migration/LICENSE)

This package contains the abstract classes for implementing database migration in Angel3 framework. It is designed to work with Angel3 ORM. Please refer to the implementation in the [ORM Migration Runner](<https://pub.dev/packages/angel3_migration_runner>) package for more details.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_migration: ^10.0.0
```

## Usage

A migration creates the tables of a model in `up`, and drops them in `down`. `angel3_orm_generator` generates one for each model, so you will rarely write one yourself:

```dart
import 'package:angel3_migration/angel3_migration.dart';

class UserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('users', (table) {
      table
        ..serial('id').primaryKey()
        ..varChar('username', length: 32).unique()
        ..varChar('password')
        ..boolean('account_confirmed').defaultsTo(false);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('users');
  }
}
```

Run migrations with [`angel3_migration_runner`](https://pub.dev/packages/angel3_migration_runner).

## Supported Features

* Create tables based on ORM models
* Drop tables based on ORM models
* Add new tables based on ORM models

## Default Values

`defaultsTo` takes the default of a column as a value, which is written as a literal: a `String` is quoted and escaped, so it is never run as SQL. For SQL, such as the current time, give a `RawSql` of `package:angel3_orm`:

```dart
table.varChar('status').defaultsTo('active');
table.timeStamp('created_at').defaultsTo(currentTimestamp);
```

## Limitation

* Alter table/fields based on updated ORM models is not supported

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **`Migration.name`** identifies a migration in the `migrations` table (default: its class name). Override it to keep a migration's record when its class is renamed, or when the program is compiled with `--obfuscate`. A class that `implements Migration`, rather than extending it, must add it.
* **`changeColumnType`** of `MutableTable` takes the `length`, `precision` and `scale` of the new type, the column's constraints after the change (`isNullable`, `defaultValue`, `autoIncrement`, kept when not given) and, on PostgreSQL, `using`. Without a precision, a `numeric` or `decimal` is unbounded on PostgreSQL, where it was `numeric(17, 3)`; give the precision and scale to keep it so. An implementation of `MutableTable` must add these parameters.
* **Defaults**: a `String` given to `defaultsTo` is a literal. Give SQL as a `RawSql`; see [Default Values](#default-values).
