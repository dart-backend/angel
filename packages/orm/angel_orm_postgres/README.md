# Angel3 ORM for PostgreSQL

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_postgres?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/angel_orm_postgres/LICENSE)

Angel3 ORM for PostgreSQL database for PostgreSQL 10 or greater.

For documentation about the ORM, see [Developer Guide](https://angel3-docs.dukefirehawk.com/guides/orm)

## Migrating to 8.1.0 and above

`postgres` has been upgraded from 2.x.x to 3.x.x since version 8.1.0. This is a breaking change as `postgres` 3.x.x has majorly changed its API. Therefore when upgrading to 8.1.0 and beyond, the PostgreSQL connection settings need to be migrated. The rest should remain the same. Please see the example for the new PostgreSQL connection settings.
