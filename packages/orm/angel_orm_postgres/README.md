# Angel3 ORM for PostgreSQL

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_postgres?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/angel_orm_postgres/LICENSE)

PostgreSQL support for Angel3 ORM.

## Supported database

* PostgreSQL version 10 or greater

For documentation about the ORM, see [Developer Guide](https://angel3-docs.dukefirehawk.com/guides/orm)

## Migration

### From version 7.x to 8.1.x

`postgres` has been upgraded from 2.x.x to 3.x.x since version 8.1.0. This is a breaking change as `postgres` 3.x.x has majorly changed its API. Therefore when upgrading to 8.1.0 and beyond, the PostgreSQL connection settings need to be migrated. The rest should remain the same. Please see the example for the new PostgreSQL connection settings.
