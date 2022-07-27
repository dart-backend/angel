# Angel3 Migration Runner

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_migration_runner?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/orm/angel_migration_runner/LICENSE)

Database migration runner for Angel3 ORM.

Supported database:

* PostgreSQL 10.x or greater
* MariaDB 10.2.x or greater
* MySQL 8.x or greater

## Usage

* Use `PostgresMigrationRunner` to perform database migration for PostgreSQL.

* Use `MySqlMigrationRunner` to perform database migration for MySQL and MariaDB. This runner is using [`mysql_client`](https://pub.dev/packages?q=mysql_client) driver.

* Use `MariaDbMigrationRunner` to perform database migration for MariaDB. This runner is using[`mysql1`](https://pub.dev/packages?q=mysql1) driver.

## Supported Operations

* reset - Clear out all records in the `migrations` table and drop all the managed ORM tables.
* up - Generate all the managed ORM tables based on the ORM models.
* refresh - Run `reset` follow by `up`
