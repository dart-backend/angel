# Angel3 ORM

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/orm/LICENSE)

Runtime support for Angel3 ORM. Includes a clean, database-agnostic query builder and the loading of relations:

* `@HasOne` and `@BelongsTo` are joined, as each record is one row.
* `@HasMany` and `@ManyToMany` are loaded after the records, with one query for all of them, as a join would return a row per item.

See [Loading Relations](https://github.com/dart-backend/angel/tree/master/packages/orm#loading-relations) for details.

## Supported database

* PostgreSQL version 10 or later
* MariaDB 10.2.x or later
* MySQL 8.x or later

For documentation about the ORM, see [Developer Guide](https://angel3-docs.dukefirehawk.com/guides/orm)
