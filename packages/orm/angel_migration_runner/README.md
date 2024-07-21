# Angel3 Migration Runner

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_migration_runner?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/angel_migration_runner/LICENSE)

This package contains the implementation of the database migration for the following databases. It is designed to work with Angel3 ORM.

* PostgreSQL 10.x or greater
* MariaDB 10.2.x or greater
* MySQL 8.x or greater

## Usage

* Use `PostgresMigrationRunner` to perform database migration for PostgreSQL.
* Use `MySqlMigrationRunner` to perform database migration for MySQL and MariaDB. This runner is using [`mysql_client`](https://pub.dev/packages?q=mysql_client) driver.
* Use `MariaDbMigrationRunner` to perform database migration for MariaDB. This runner is using [`mysql1`](https://pub.dev/packages?q=mysql1) driver.

## Supported Operations

* up      - Generate all the tables based on the ORM models.
* reset   - Clear out all records in the `migrations` table and drop all the ORM related tables.
* refresh - Run `reset` follow by `up`

## Limitation

* Update schema changes is not supported
