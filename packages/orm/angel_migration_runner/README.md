# Angel3 Migration Runner

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_migration_runner?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/orm/angel_migration_runner/LICENSE)

Command-line based database migration runner for Angel3 ORM.

Supported database:

* PostgreSQL version 10 or later
* MariaDB 10.2.x or later
* MySQL 8.x or later

## Usage

* For PostgreSQL, use `PostgresMigrationRunner` to perform the database migration.

* For MariaDB, use `MariaDbMigrationRunner` to perform the database migration.

* For MySQL, use `MySqlMigrationRunner` to perform the database migration.

**Important Notes** For MariaDB and MySQL, both migration runner are using different drivers. MariaDB is using `mysql1` driver while MySQL is using `mysql_client` driver. This is necessary as neither driver works correctly over both MariaDB and MySQL. Based on testing, `mysql1` driver works seamlessly with MariaDB 10.2.x while `mysql_client` works well with MySQL 8.x.
