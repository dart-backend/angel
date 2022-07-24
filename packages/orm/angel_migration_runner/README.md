# Angel3 Migration Runner

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_migration_runner?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/orm/angel_migration_runner/LICENSE)

Database migration runner for Angel3 ORM.

Supported database:

* PostgreSQL version 10 or later
* MariaDB 10.2.x or later
* MySQL 8.x or later

## Usage

* Use `PostgresMigrationRunner` to perform the database migration for PostgreSQL.

* Use `MySqlMigrationRunner` to perform the database migration for MySQL and MariaDB. This is implemented with [`mysql_client`](https://pub.dev/packages?q=mysql_client) driver.

* Use `MariaDbMigrationRunner` to perform the database migration for MariaDB. [`mysql1`](https://pub.dev/packages?q=mysql1).
