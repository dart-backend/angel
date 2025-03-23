# Angel3 Migration

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_migration?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/angel_migration/LICENSE)

This package contains the abstract classes for implementing database migration in Angel3 framework. It is designed to work with Angel3 ORM. Please refer to the implementation in the [ORM Migration Runner](<https://pub.dev/packages/angel3_migration_runner>) package for more details.

## Supported Features

* Create tables based on ORM models
* Drop tables based on ORM models
* Add new tables based on ORM models

## Limitation

* Alter table/fields based on updated ORM models is not supported
