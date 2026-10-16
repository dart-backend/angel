# Change Log

## 10.0.0

* **Breaking:** No longer uses `dart:mirrors`, so apps using it can be compiled with `dart compile exe`. In an expression such as `{{user.name}}`, each part after the first is read as a key of a `Map`, or of what the object's `toJson()` returns (as for `@serializable` models). The getters of other objects are no longer read
* fix: Expressions into `Map` locals, such as `{{user.name}}` with `{'user': {'name': 'Bob'}}`, resolve; they threw `NoSuchMethodError`
* fix: A missing key, a `null` value or an object without `toJson()` in the middle of an expression throws an `ArgumentError` naming the expression
* test: Added tests for interpolation
* Released with the other Angel3 packages at 10.0.0

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

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
* Fixed linter warnings

## 8.0.0

* Require Dart >= 3.0

## 7.0.0

* Require Dart >= 2.17
* Updated `markdown` to 6.0.x

## 6.1.0

* Updated `markdown` to 5.x.x

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Updated linter to `package:lints`

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD
  
## 3.0.0

* Migrated to support Dart >= 2.12 Non NNBD

## 2.0.0

* Angel 2 + Dart 2 updates.
* Use `package:file`.
