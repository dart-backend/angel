# Angel3 Migration

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_migration?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/migration/LICENSE)

This package contains the abstract classes for implementing database migration in Angel3 framework. It is designed to work with Angel3 ORM. Please refer to the implementation in the [ORM Migration Runner](<https://pub.dev/packages/angel3_migration_runner>) package for more details.

## Supported Features

* Create tables based on ORM models
* Drop tables based on ORM models
* Add new tables based on ORM models

## Default Values

`defaultsTo` takes the default of a column as a value, which is written as a literal: a `String` is quoted and escaped, so it is never run as SQL. For SQL, such as the current time, give a `RawSql` of `package:angel3_orm`:

```dart
table.varChar('status').defaultsTo('active');
table.timeStamp('created_at').defaultsTo(currentTimestamp);
```

## Limitation

* Alter table/fields based on updated ORM models is not supported
