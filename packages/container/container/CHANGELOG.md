# Change Log

## 10.0.0

* fix!: `Container.make` no longer fails for constructor parameters with a default value (e.g. `[int retries = 3]`) when nothing is registered for their type; they now keep their default. An optional positional parameter whose type is not registered is now left out (`null` or its default), instead of being constructed by reflection
* refactor!: Removed `package:angel3_container/mirrors.dart`. `MirrorsReflector` is now in the new `angel3_container_mirrors` package (`package:angel3_container_mirrors/angel3_container_mirrors.dart`), so `angel3_container` no longer depends on `dart:mirrors`
* feat: Added `ReflectedParameter.hasDefaultValue`, set by `MirrorsReflector`
* fix: `Container.make` with `MirrorsReflector` no longer ignores named constructor parameters: required ones failed with `NoSuchMethodError`, and optional ones were left `null`
* fix: `Container.make` now leaves out an optional named parameter whose type is not registered and cannot be constructed (e.g. `{String? prefix}`), instead of failing
* fix: `Container.make` leaves out an optional named parameter only when its type cannot be constructed (no reflection data, no default constructor, abstract or circular); errors thrown by a constructor or factory are no longer swallowed
* fix: `Container.make` now throws a `ReflectionException` for a circular dependency, instead of overflowing the stack, and leaves out an optional named parameter of the type being made (e.g. `Node({Node? next})`)
* fix: Child containers now get their own `registerLazySingleton` instance, even after the container it was registered on has made one; they used to get that container's instance
* fix: `registerLazySingleton` now returns `f`, as documented, instead of the factory wrapping it

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12
* Refactored code

## 8.4.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.1.1

* Updated repository link

## 8.1.0

* Updated `lints` to 3.0.0
* Fixed analyser warnings

## 8.0.0

* Require Dart >= 3.0

## 7.1.0-beta.2

* Require Dart >= 2.19
* Refactored `EmptyReflector`

## 7.1.0-beta.1

* Require Dart >= 2.18
* Moved `defaultErrorMessage` to `ContainerConst` class to resolve reflectatable issue.
* Added `hashCode`

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16
* Removed `error`

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release
  
## 3.1.1

* Updated `_ReflectedMethodMirror` to have optional `returnType` parameter
* Updated `Container` to handle non nullable type

## 3.1.0

* Updated linter to `package:lints`

## 3.0.2

* Resolved static analysis warnings

## 3.0.1

* Updated README

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD

## 2.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 1.1.0

* `pedantic` lints.
* Add `ThrowingReflector`, which throws on all operations.
* `EmptyReflector` uses `Object` instead of `dynamic` as its returned
type, as the `dynamic` type is (apparently?) no longer a valid constant value.
* `registerSingleton` now returns the provided `object`.
* `registerFactory` and `registerLazySingleton` now return the provided function `f`.

## 1.0.4

* Slight patch to prevent annoying segfault.

## 1.0.3

* Added `Future` support to `Reflector`.

## 1.0.2

* Added `makeAsync<T>`.

## 1.0.1

* Added `hasNamed`.

## 1.0.0

* Removed `@GenerateReflector`.

## 1.0.0-alpha.12

* `StaticReflector` now defaults to empty arguments.

## 1.0.0-alpha.11

* Added `StaticReflector`.

## 1.0.0-alpha.10

* Added `Container.registerLazySingleton<T>`.
* Added named singleton support.

## 1.0.0-alpha.9

* Added `Container.has<T>`.

## 1.0.0-alpha.8

* Fixed a bug where `_ReflectedTypeInstance.isAssignableTo` always failed.
* Added `@GenerateReflector` annotation.

## 1.0.0-alpha.7

* Add `EmptyReflector`.
* `ReflectedType.newInstance` now returns a `ReflectedInstance`.
* Moved `ReflectedInstance.invoke` to `ReflectedFunction.invoke`.

## 1.0.0-alpha.6

* Add `getField` to `ReflectedInstance`.

## 1.0.0-alpha.5

* Remove concrete type from `ReflectedTypeParameter`.

## 1.0.0-alpha.4

* Safely handle `void` return types of methods.

## 1.0.0-alpha.3

* Reflecting `void` in `MirrorsReflector` now forwards to `dynamic`.

## 1.0.0-alpha.2

* Added `ReflectedInstance.reflectee`.

## 1.0.0-alpha.1

* Allow omission of the first argument of `Container.make`, to use
a generic type argument instead.
* `singleton` -> `registerSingleton`
* Add `createChild`, and support hierarchical containers.
