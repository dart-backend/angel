# Angel3 ORM Generator

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_generator?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/orm_generator/LICENSE)

The builder for generating the following code for Angel3 ORM:

* Strongly-typed ORM classes
* SQL migration classes

For documentation about the ORM, see [Developer Guide](https://angel3-docs.dukefirehawk.com/guides/orm)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_orm: ^10.1.0
  angel3_serialize: ^10.0.0
  angel3_migration: ^10.0.0
dev_dependencies:
  angel3_orm_generator: ^10.0.0
  build_runner: ^2.4.0
```

## Models

Name a model class with the `Entity` suffix, such as `CarEntity`. The generated classes are named without it: `Car`, `CarQuery`, `CarQueryWhere`, `CarQueryValues` and `CarMigration`, and the table is `cars`.

A class with the `_` prefix, such as `_Car`, generates the same classes. A class with both, such as `_CarEntity`, also generates `Car`, but keeps the table, `car_entities`, that versions before 10.0.0 gave it.

## Usage

Annotate a model with `@serializable` and `@orm`, in `car.dart`:

```dart
import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

part 'car.g.dart';

@serializable
@orm
abstract class CarEntity extends Model {
  String? get make;

  bool? get familyFriendly;
}
```

Run the following command to generate the required `.g.dart` files for Angel3 ORM.

```bash
    dart run build_runner build
```

## String primary keys

A model that extends `Model` has an `id` that is an integer key, `serial`, which the database assigns. Declare another column type on `id`, as a UUID, and it is a key of that type, a `String`:

```dart
@serializable
@orm
abstract class UserEntity extends Model {
  @override
  @Column(type: ColumnType('uuid'), indexType: IndexType.primaryKey)
  String? get id;

  String? get name;
}
```

* **Migration.** The column of `id` is of the type declared, and the foreign keys of other models that refer to it are of the same type and length, as `author_id` of a `@BelongsTo UserEntity author`.
* **Queries.** `where.id` is a `StringSqlExpressionBuilder`, so `UserQuery()..where!.id.equals(uuid)` reads a user by its UUID, and `values.id` sets it.
* **Its value.** Give the `id` of each insert, as of `package:uuid`: `UserQuery()..values.id = Uuid().v4()`. A default of the database, as `gen_random_uuid()`, cannot be declared yet: `@Column(defaultValue: RawSql(...))` does not generate. On MySQL and MariaDB, the inserted row is found by the `id` given, so an `id` must be given there in any case.
* **Types.** `uuid` is of PostgreSQL. MySQL and MariaDB have none: use `@Column(type: ColumnType.char, length: 36, ...)`, or `varChar`. SQLite takes `ColumnType.text`.

An `id` of no column type, or of an integer one, as `ColumnType.bigSerial`, is an integer key, as before.

## JSON columns

A field of a `@serializable` class that is not a model of its own, such as a profile, is stored as JSON, in a `jsonb` column on PostgreSQL:

```dart
@serializable
@orm
abstract class UserEntity extends Model {
  String? get name;

  ProfileEntity? get profile;
}

@serializable
abstract class ProfileEntity {
  String? get firstName;

  String? get lastName;
}
```

* **Stored and read** with the class's serializer: `ProfileSerializer.toMap` when written, and `ProfileSerializer.fromMap` when read, of the map that PostgreSQL gives or the JSON text of MySQL, MariaDB and SQLite.
* **Queried** as a map: `UserQuery()..where!.profile['first_name'].asString?.equals('Ana')`.
* **Nullable or not.** A nullable one, as `ProfileEntity?`, is `NULL` when it is `null`. A non-nullable one needs `angel3_serialize_generator` 10.1.0 or later, and must be among the fields of a query that reads it.

A field of a type that the generator cannot store, or query, is left out of the query's `where` with a warning, rather than generating code that does not compile.

## Supported database

* PostgreSQL version 16 or later
* MariaDB 10.2.x or later
* MySQL 8.x or later

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **Regenerate** your models with `dart run build_runner build --delete-conflicting-outputs`, with `angel3_orm` 10.
* **Relations**: `@HasMany` and `@ManyToMany` are loaded with a query each instead of joins. A generated query no longer overrides `get`, `update`, `delete` or `canCompile`, and overrides `loadRelations` and `loadsRelations` instead; code that called the old overrides directly needs no change. See [Migrating from 9.x to 10.0.0 of `angel3_orm`](https://github.com/dart-backend/angel/tree/master/packages/orm/orm#migrating-from-9x-to-100).
* **Relation keys**: the key of a relation in `QueryValues`, such as `authorId` of a `@BelongsTo AuthorEntity author`, is nullable (`int?`):

  ```dart
  // 9.x
  int authorId = query.values.authorId;

  // 10.0.0
  int? authorId = query.values.authorId;
  ```

* **Code that uses the generator's API**: `OrmBuildContext.effectiveFields` is a `List<OrmField>` (`ClassOrmField` or `RelationFieldImpl`), as are the arguments of `findPrimaryFieldInList`, `isSpecialId`, `findLocalField` and `findForeignField`.
