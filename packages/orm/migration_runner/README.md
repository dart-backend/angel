# Angel3 Migration Runner

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_migration_runner?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/migration_runner/LICENSE)

This package contains the implementation of the database migration for the following databases. It is designed to work with Angel3 ORM.

* PostgreSQL 14.x or greater
* MariaDB 10.2.x or greater
* MySQL 8.x or greater

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_migration_runner: ^10.0.0
```

## Usage

* Use `PostgresMigrationRunner` to perform database migration for PostgreSQL.
* Use `MySqlMigrationRunner` to perform database migration for MySQL. This runner is using [`mysql_dart`](https://pub.dev/packages/mysql_dart) driver.
* Use `MariaDbMigrationRunner` to perform database migration for MariaDB. This runner is using [`mysql_dart`](https://pub.dev/packages/mysql_dart) driver.

Run the migrations from a command-line program, such as `bin/migrate.dart`, with `runMigrations`:

```dart
import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_migration_runner/postgres.dart';
import 'package:postgres/postgres.dart';

import 'todo.dart';

void main(List<String> args) async {
  var connection = await Connection.open(
    Endpoint(
      host: 'localhost',
      database: 'demo',
      username: 'demouser',
      password: 'demo123',
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );

  var runner = PostgresMigrationRunner(
    connection,
    migrations: [UserMigration(), TodoMigration()],
  );

  // `dart bin/migrate.dart up`, `rollback`, `reset` or `refresh`
  await runMigrations(runner, args);
}
```

See [example/main.dart](example/main.dart) for MySQL too.

## Supported Operations

* up       - Run the migrations not recorded in the `migrations` table yet, in a new batch, to generate the tables based on the ORM models. A migration that fails throws, and none after it is run, as they may depend on it.
* rollback - Undo the migrations of the last batch, newest first.
* reset    - Undo every migration, newest first, and clear out its records in the `migrations` table, which drops all the ORM related tables.
* refresh  - Run `reset` followed by `up`.

`runMigrations(runner, args)` runs these as the commands of a command-line program, and closes the runner, even when a migration fails.

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

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **Migration names**: a migration is recorded by its `Migration.name`, where it was its source path and class name. Rows recorded by 9.x are renamed on the first run; see [Upgrading from 9.x](#upgrading-from-9x).
* **MySQL and MariaDB**: `MySqlMigrationRunner`, `MariaDbMigrationRunner` and `MariaDbSchema.run` use [`mysql_dart`](https://pub.dev/packages/mysql_dart), instead of `mysql_client` and `mysql1`. Pass its `MySQLConnection`, and import `package:mysql_dart/mysql_dart.dart`.
* **Failures**: `up` of every runner throws when a migration fails, and runs none after it, where the PostgreSQL and MariaDB runners only logged it. `MySqlSchema.run` throws when its SQL fails.
* **Duplicate names**: two migrations of the same name throw a `StateError`, including two of one class that takes arguments; give each its own `name`.
* **String defaults** are quoted and escaped alike on every database: give `defaultsTo('active')`, not `"'active'"`, and SQL as `RawSql`, e.g. `defaultsTo(RawSql('CURRENT_TIMESTAMP'))`.
* **`numeric` and `decimal`** columns are created with their precision and scale, where MySQL and MariaDB rounded values to whole numbers. Without them they are `numeric(17, 3)` on MySQL and MariaDB, and unbounded on PostgreSQL.
* **`changeColumnType`** takes the `precision`, `scale` and `length` of the new type (default length 255), the constraints after the change, and `using` on PostgreSQL.
* **Table names** are quoted per part: `` `shop`.`orders` `` on MySQL and MariaDB, `"audit"."events"` on PostgreSQL. A PostgreSQL table with a `.` in its own name must be given in double quotes.
