# Angel3 ORM Generator

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_generator?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/orm_generator/LICENSE)

The builder for generating the following code for Angel3 ORM:

* Strongly-typed ORM classes
* SQL migration classes

For documentation about the ORM, see [Developer Guide](https://angel3-docs.dukefirehawk.com/guides/orm)

## Models

Name a model class with the `Entity` suffix, such as `CarEntity`. The generated classes are named without it: `Car`, `CarQuery`, `CarQueryWhere`, `CarQueryValues` and `CarMigration`, and the table is `cars`.

A class with the `_` prefix, such as `_Car`, generates the same classes. A class with both, such as `_CarEntity`, also generates `Car`, but keeps the table, `car_entities`, that versions before 10.0.0 gave it.

## Usage

Run the following command to generate the required `.g.dart` files for Angel3 ORM.

```bash
    dart run build_runner build
```

## Supported database

* PostgreSQL version 10 or later
* MariaDB 10.2.x or later
* MySQL 8.x or later
