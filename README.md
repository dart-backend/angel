# orm
[![Pub](https://img.shields.io/pub/v/angel_orm.svg)](https://pub.dartlang.org/packages/angel_orm)
[![build status](https://travis-ci.org/angel-dart/orm.svg)](https://travis-ci.org/angel-dart/orm)

Source-generated PostgreSQL ORM for use with the
[Angel framework](https://angel-dart.github.io).
Now you can combine the power and flexibility of Angel with a strongly-typed ORM.

* [Usage](#usage)
* [Model Definitions](#models)
* [MVC Example](#example)
* [Relationships](#relations)
  * [Many-to-Many Relationships](#many-to-many-relations)
* [Columns (`@Column(...)`)](#columns)
    * [Column Types](#column-types)
    * [Indices](#indices)
    * [Default Values](#default-values)

# Usage
You'll need these dependencies in your `pubspec.yaml`:
```yaml
dependencies:
  angel_orm: ^2.0.0-dev
dev_dependencies:
  angel_orm_generator: ^2.0.0-dev
  build_runner: ^1.0.0
```

`package:angel_orm_generator` exports a class that you can include
in a `package:build` flow:
* `PostgresOrmGenerator` - Fueled by `package:source_gen`; include this within a `SharedPartBuilder`.

However, it also includes a `build.yaml` that builds ORM files automatically, so you shouldn't
have to do any configuration at all.

# Models
Your model, courtesy of `package:angel_serialize`:

```dart
library angel_orm.test.models.car;

import 'package:angel_framework/common.dart';
import 'package:angel_orm/angel_orm.dart';
import 'package:angel_serialize/angel_serialize.dart';
part 'car.g.dart';

@serializable
@orm
abstract class _Car extends Model {
  String get make;

  String get description;

  bool get familyFriendly;

  DateTime get recalledAt;
}

// You can disable migration generation.
@Orm(generateMigrations: false)
abstract class _NoMigrations extends Model {}
```

Models can use the `@Alias()` annotation; `package:angel_orm` obeys it.

After building, you'll have access to a `Query` class with strongly-typed methods that
allow to run asynchronous queries without a headache.

**IMPORTANT:** The ORM *assumes* that you are using `package:angel_serialize`, and will only generate code
designed for such a workflow. Save yourself a headache and build models with `angel_serialize`:

https://github.com/angel-dart/serialize

Remember that if you don't need automatic id-and-date fields, you can do the following:

```dart
@Serializable(autoIdAndDateFields: false)
abstract class _ThisIsNotAnAngelModel {

}
```

# Example

MVC just got a whole lot easier:

```dart
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_orm/angel_orm.dart';
import 'car.dart';
import 'car.orm.g.dart';

/// Returns an Angel plug-in that connects to a database, and sets up a controller connected to it...
AngelConfigurer connectToCarsTable(QueryExecutor executor) {
  return (Angel app) async {
    // Register the connection with Angel's dependency injection system.
    // 
    // This means that we can use it as a parameter in routes and controllers.
    app.container.registerSingleton(executor);
    
    // Attach the controller we create below
    await app.mountController<CarController>();
  };
}

@Expose('/cars')
class CarController extends Controller {
  // The `executor` will be injected.
  @Expose('/recalled_since_2008')
  carsRecalledSince2008(QueryExecutor executor) {
    // Instantiate a Car query, which is auto-generated. This class helps us build fluent queries easily.
    var cars = new CarQuery();
    cars.where
      ..familyFriendly.equals(false)
      ..recalledAt.year.greaterThanOrEqualTo(2008);
    
    // Shorter syntax we could use instead...
    cars.where.recalledAt.year <= 2008;
    
    // `get()` returns a Future<List<Car>>.
    return await cars.get(executor);
  }
  
  @Expose('/create', method: 'POST')
  createCar(QueryExecutor executor) async {
    // `package:angel_orm` generates a strongly-typed `insert` function on the query class.
    // Say goodbye to typos!!!
    var query = new CarQuery();
    query.values
      ..familyFriendly = true
      ..make 'Honda';
    var car = query.insert(executor);
    
    // Auto-serialized using code generated by `package:angel_serialize`
    return car;
  }
}
```

# Relations
`angel_orm` supports the following relationships:

* `@HasOne()` (one-to-one)
* `@HasMany()` (one-to-many)
* `@BelongsTo()` (one-to-one)

The annotations can be abbreviated with the default options (ex. `@hasOne`), or supplied
with custom parameters (ex. `@HasOne(foreignKey: 'foreign_id')`).

```dart
@serializable
@orm
abstract class _Author extends Model {
  @hasMany // Use the defaults, and auto-compute `foreignKey`
  List<Book> books;
  
  // Also supports parameters...
  @HasMany(localKey: 'id', foreignKey: 'author_id', cascadeOnDelete: true)
  List<Book> books;
  
  @Alias('writing_utensil')
  @hasOne
  Pen pen;
}
```

The relationships will "just work" out-of-the-box, following any operation. For example,
after fetching an `Author` from the database in the above example, the `books` field would
be populated with a set of deserialized `Book` objects, also fetched from the database.

Relationships use joins when possible, but in the case of `@HasMany()`, two queries are used:
* One to fetch the object itself
* One to fetch a list of related objects

## Many to Many Relations
A many-to-many relationship can now be modeled like so.
`UserRole` in this case is a pivot table joining `User` and `Role`.

Note that in this case, the models must reference the private classes (`_User`, etc.), because the canonical versions (`User`, etc.) are not-yet-generated:

```dart
library angel_orm_generator.test.models.user;

import 'package:angel_model/angel_model.dart';
import 'package:angel_orm/angel_orm.dart';
import 'package:angel_serialize/angel_serialize.dart';
import 'package:collection/collection.dart';
part 'user.g.dart';

@serializable
@orm
abstract class _User extends Model {
  String get username;
  String get password;
  String get email;

  @hasMany
  List<_UserRole> get userRoles;

  List<_Role> get roles => userRoles.map((m) => m.role).toList();
}

@serializable
@orm
abstract class _Role extends Model {
  String name;

  @hasMany
  List<_UserRole> get userRoles;

  List<_User> get users => userRoles.map((m) => m.user).toList();
}

@Serializable(autoIdAndDateFields: false)
@orm
abstract class _UserRole {
  int get id;

  @belongsTo
  _User get user;

  @belongsTo
  _Role get role;
}
```

TLDR: 
1. Make a pivot table, C, between two tables, table A and B
2. C should `@belongsTo` both A and B.
3. Both A and B should `@hasMany` C.
4. For convenience, write a simple getter, like the above `User.roles`.

Test: https://raw.githubusercontent.com/angel-dart/orm/master/angel_orm_generator/test/many_to_many_test.dart

There are 2 tests there, but they are more or less a proof-of-concept. All the logic for the other relations have their own unit tests.

# Columns
Use a `@Column()` annotation to change how a given field is handled within the ORM.

## Column Types
Using the `@Column()` annotation, it is possible to explicitly declare the data type of any given field:

```dart
@serializable
@orm
abstract class _Foo extends Model {
  @Column(type: ColumnType.bigInt)
  int bar;
}
```

## Indices
Columns can also have an `index`:

```dart
@serializable
@orm
abstract class _Foo extends Model {
  @Column(index: IndexType.primaryKey)
  String bar;
}
```

## Default Values
It is also possible to specify the default value of a field.
**Note that this only works with primitive objects.**

If a default value is supplied, the `SqlMigrationBuilder` will include
it in the generated schema. The `PostgresOrmGenerator` ignores default values;
it does not need them to function properly.

```dart
@serializable
@orm
abstract class _Foo extends Model {
  @Column(defaultValue: 'baz')
  String bar;
}
```