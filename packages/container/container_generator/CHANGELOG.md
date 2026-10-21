# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Rewritten as a `build_runner` builder of reflection data for `@injectable` classes and top-level functions, used through `StaticReflector`, so that `Container.make`, `@Expose` controllers, `@Hooks`/`@Middleware` and `ioc` work without `dart:mirrors`, also in AOT and obfuscated apps. It no longer depends on `reflectable`
* **Breaking:** Removed `GeneratedReflector`, `ContainedReflectable` and `contained`. To migrate:
  * Replace `@contained` with `@injectable` (from `package:angel3_container`), and add `part '<file>.g.dart';` to each library with such classes
  * Replace `reflectable_builder` with `angel3_container_generator` and `build_runner` in `dev_dependencies`, and run `dart run build_runner build`
  * Replace `GeneratedReflector()` with `StaticReflector.combine([...])`, passing each library's generated variable (e.g. `servicesReflection` for `services.dart`)
* **Breaking:** Closures cannot be described: `ioc` on a closure needs an explicit `injection:`

### New in 10.0.0

* The data of a class lists its `supertypes` (e.g. so a `WebSocketController` finds inherited `@ExposeWs` methods)
* `getMember` reads public fields, getters and methods, declared or inherited, and returns `noStaticMember` for other names. Regenerate the data with `dart run build_runner build`

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
