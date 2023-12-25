# Angel3 ORM Generator

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_generator?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/angel3_orm_generator/LICENSE)

Source code generators for Angel3 ORM. This package can generate:

* A strongly-typed ORM
* SQL migration scripts

For documentation about the ORM, see [Developer Guide](https://angel3-docs.dukefirehawk.com/guides/orm)

## Usage

Run the following command to generate the required `.g.dart` files for Angel3 ORM.

```bash
    dart run build_runner build
```

## Supported database

* PostgreSQL version 10 or later
* MariaDB 10.2.x
* MySQL 8.x
