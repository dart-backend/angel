# Change Log

## 10.0.0

* `ReflectedParameter.hasDefaultValue` is now set (with `contained`, or any `Reflectable` that has a `DeclarationsCapability`), so DI keeps the default of an unresolved parameter, as with `MirrorsReflector`
* Fixed `GeneratedReflector.getName` returning `"name")` instead of `name`
* Fixed `ReflectedFunction.invoke` always failing: it threw when a closure was available, and failed with a null error when one was not
* `ReflectedClass.declarations` now lists only methods (including getters and setters), like `MirrorsReflector`; fields (with no function) and constructors are no longer included
* `ReflectedInstance.getField` now returns values that `reflectable` cannot reflect (e.g. `null` or a method tear-off), instead of throwing
* Parameters whose type `reflectable` cannot reflect are now described by their `Type`, instead of making the whole function fail to reflect

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.4.0

* Require Dart >= 3.9
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

## 7.1.0-beta.1

* Require Dart >= 2.19
* Upgraded `relectable` to 4.x.x

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.0.1

* Updated `package:angel3_container`

## 3.0.0

* Fixed NNBD issues
* All 9 test cases passed

## 3.0.0-beta.1

* Migrated to support Dart >= 2.12 NNBD
* Updated linter to `package:lints`
* Updated to use `angel3_` packages

## 2.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 1.0.1

* Update for `pkg:angel_container@1.0.3`.
