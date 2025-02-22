# Change Log

## 8.4.1

* Fixed `ShimFieldImpl` due to breaking changes in `analyzer` 7.3.0

## 8.4.0

* Require Dart >= 3.6
* Updated `lints` to 5.x
* Updated `source_gen` to 2.x
* Updated `analyzer` to 7.x
* Updated dependencies to the latest release
* Updated `ShimFieldImpl`

## 8.3.1

* Updated dependencies

## 8.3.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.2.1

* Updated repository link

## 8.2.0

* Updated `lints` to 3.0.0
* Fixed linter warnings

## 8.1.0

* Upgraded to `analyzer` 6.2.x

## 8.0.1

* Fixed `JsonModelGenerator` from generating duplicated fields
* Fixed `JsonModelGenerator` to priortize `id` field as the first argument

## 8.0.0

* Require Dart >= 3.0

## 7.2.0-beta.1

* Require Dart >= 2.19
* Fixed `topMap` incorrect return

## 7.1.0

* Require Dart >= 2.18
* Upgraded to `analyzer` 5.x.x
* Replaced deprecated `element2` with `element`

## 7.0.0

* Require Dart >= 2.17
* Fixed enum test cases
* Resolved deprecated methods

## 6.1.1

* Fixed issue #68: Support for non-nullable type

## 6.1.0

* Updated to `analyzer` 4.x.x

## 6.0.0

* Require Dart >= 2.16
* Updated to `analyzer` 3.x.x
* Fixed default value for `List` and `Enum`

## 5.0.0

* Skipped release

## 4.3.0

* Updated to use  `package:belatuk_code_buffer`

## 4.2.0

* Fixed `toMap` method generation for non nullable Map
* Fixed `fromMap` method generation for non nullable Map
* Updated linter to `package:lints`

## 4.1.2

* Fixed `toMap` method generation
* Fixed `fromMape` method generation
* Fixed `TypescriptBuilder`
* Updated generator to add `const []` to `List` type args in the contructor
* Updated generator to product non nullable aware code
* Refactored away nullable code
* Added logging to facilitate tracing the code generation via `-verbose` flag
* Removed redudant null checking in the generated code

## 4.1.1

* Fixed `SerializerGenerator` to recognize nullable class

## 4.1.0

* Upgraded to support `analyzer` 2.0.0 major release

## 4.0.3

* Added `useNullSafetySyntax: true` to DartEmitter
* Fixed `JsonModelGenerator` class to produce correct NNBD code
  * Replaced `@required` with `required`
  * Fixed all none nullable field to be `required` in the constructor
  * Fixed generated methods to return the correct type
  * Fixed generated methods to be annnotated with `override` where applicable
  * Removed redundant null checking in the generated code

## 4.0.2

* Fixed `build.yaml` to use `angel3` packages
* Updated README

## 4.0.1

* Resolved static analysis warnings

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD
* Importing `Optional` package is required for the ORM model

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.5.0

* Support mutable models (again).
* Use `whereType()` instead of chaining `where()` and `cast()`.
* Support pulling fields from parent classes and interfaces.
* Only generate `const` constructors if *all*
fields lack a setter.
* Don't type-annotate initializing formals.

## 2.4.4

* Remove unnecessary `new` and `const`.

## 2.4.3

* Generate `Codec` and `Converter` classes.
* Generate `toString` methods.
* Include original documentation comments from the model.

## 2.4.2

* Fix bug where enums didn't support default values.
* Stop emitting `@required` on items with default values.
* Create default `@SerializableField` for fields without them.

## 2.4.1+1

* Change `as Iterable<Map>` to `.cast<Map>`.

## 2.4.1

* Support `serializesTo`.
* Don't emit `@required` if there is a default value.
* Deprecate `autoIdAndDateFields`.

## 2.4.0

* Introduce `@SerializableField`, and say goodbye to annotation hell.
* Support custom (de)serializers.
* Allow passing of annotations to the generated class.
* Fixted TypeScript `ref` generator.

## 2.3.0

* Add `@DefaultValue` support.

## 2.2.2

* Split out TS def builder, to emit to source.

## 2.2.1

* Explicit changes for assisting `angel_orm_generator`.

## 2.2.0

* Build to `cache`.
* Only generate one `.g.dart` file.
* Support for `Uint8List`.
* Use `.cast()` for `List`s and `Map`s of *non-`Model`* types.

## 2.1.2

* Add `declare module` to generated TypeScript files.

## 2.1.1

* Generate `hashCode`.

## 2.1.0

* Removed dependency on `package:id`.
* Update dependencies for Dart2Stable.
* `jsonModelBuilder` now uses `SharedPartBuilder`, rather than
`PartBuilder`.

## 2.0.10

* Generate `XFields.allFields` constant.
* No longer breaks in cases where `dynamic` is present.
* Call `toJson` in `toMap` on nested models.
* Never generate named parameters from private fields.
* Use the new `@generatedSerializable` to *always* find generated
models.

## 2.0.9+4

* Remove `defaults` in `build.yaml`.

## 2.0.9+3

* Fix a cast error when self-referencing nested list expressions.

## 2.0.9+2

* Fix previously unseen cast errors with enums.

## 2.0.9+1

* Fix a cast error when deserializing nested model classes.

## 2.0.9

* Upgrade to `source_gen@^0.8.0`.

## 2.0.8+3

* Don't fail on `null` in `toMap`.
* Support self-referencing via `toJson()`.

## 2.0.8+2

* Better discern when custom methods disqualify classes
from `const` protection.

## 2.0.8+1

* Fix generation of `const` constructors with iterables.

## 2.0.8

* Now supports de/serialization of `enum` types.
* Generate `const` constructors when possible.
* Remove `whereType`, perform manual coercion.
* Generate a `fromMap` with typecasting, for Dart 2's sake.

## 2.0.7

* Create unmodifiable Lists and Maps.
* Support `@required` on fields.
* Affix an `@immutable` annotation to classes, if
`package:meta` is imported.
* Add `/// <reference path="..." />` to TypeScript models.

## 2.0.6

* Support for using `abstract` to create immutable model classes.
* Add support for custom constructor parameters.
* Closed [##21](https://github.com/angel-dart/serialize/issues/21) - better naming
of `Map` types.
* Added overridden `==` operators.

## 2.0.5

* Deserialization now supports un-serialized `DateTime`.
* Better support for regular typed Lists and Maps in TypeScript.

## 2.0.4

* Fields in TypeScript definitions are now nullable by default.

## 2.0.3

* Added a `TypeScriptDefinitionBuilder`.

## 2.0.2

* Generates an `XFields` class with the serialized names of
all fields in a model class `X`.
* Removed unnecessary named parameters from `XSerializer.fromMap`.

## 2.0.1

* Ensured that `List` is only transformed if
it generically references a `Model`.
