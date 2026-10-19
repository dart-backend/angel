# Angel3 Migration Runner

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_migration_runner?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/migration_runner/LICENSE)

This package contains the implementation of the database migration for the following databases. It is designed to work with Angel3 ORM.

* PostgreSQL 10.x or greater
* MariaDB 10.2.x or greater
* MySQL 8.x or greater

## Usage

* Use `PostgresMigrationRunner` to perform database migration for PostgreSQL.
* Use `MySqlMigrationRunner` to perform database migration for MySQL and MariaDB. This runner is using [`mysql_dart`](https://pub.dev/packages/mysql_dart) driver.
* Use `MariaDbMigrationRunner` to perform database migration for MariaDB. This runner is using [`mysql1`](https://pub.dev/packages?q=mysql1) driver.

## Supported Operations

* up      - Generate all the tables based on the ORM models.
* reset   - Clear out all records in the `migrations` table and drop all the ORM related tables.
* refresh - Run `reset` follow by `up`

## Migration Names

Each migration is recorded in the `migrations` table by its `Migration.name`, which defaults to the name of its class. Override `name` to keep it stable:

* when the class is renamed, or two migration classes in different files have the same name, and
* when the program is compiled with `--obfuscate`, which renames classes.

A migration recorded under another name is run again.

```dart
class CreateUsersMigration extends Migration {
  @override
  String get name => 'create_users';
  ...
}
```

### Upgrading from 9.x

Versions before 10.0.0 recorded a migration as `<absolute source file>#<class name>`. On its first run, the runner renames such a row to the migration's `name` when the row's class name belongs to exactly one row and one migration. Otherwise, as when two migrations share a class name, or the project was moved and the migration was recorded at both paths, it throws a `StateError` rather than guess. For those, give the migration a `legacyPath`, the end of the path it was recorded by:

```dart
@override
String get legacyPath => 'lib/src/migrations/users.dart#UserMigration';
```

Or set each `path` of the `migrations` table to the `name` of its migration by hand.

## Transactions

On PostgreSQL, each migration runs, and is recorded in the `migrations` table, in one transaction, so a migration that fails or is cut off is neither applied nor recorded.

MySQL and MariaDB commit each change of a table on its own, so a migration is recorded once it has run. If the connection is lost between the two, the migration's changes stay without its row in the `migrations` table, and the next `up` runs it again. Insert its row by hand in that case:

```sql
INSERT INTO migrations (batch, path) VALUES (<batch>, '<name>');
```

## Limitation

* Update schema changes is not supported
