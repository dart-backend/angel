# Change Log

## 10.0.0-beta.1

* feat: The reflection data of a class lists the superclasses the library can name, as its `supertypes`, so that e.g. a `WebSocketController` finds the `@ExposeWs` methods of a base controller
* feat: The `getMember` of a class reads its public instance fields and getters, as their values, and its methods, as tear-offs, declared or inherited but of `Object`, where it read only the methods it declares; e.g. so that a template reads the members of a model. It returns `noStaticMember` for any other name, where it returned `null`. Regenerate the reflection data with `dart run build_runner build`
* The generated `_$named` helper uses a null-aware map entry (`?symbols[e.key]: e.value`), which the `use_null_aware_elements` lint asks for
* **Breaking:** Rewritten as a `build_runner` builder that generates reflection data, used through `StaticReflector`, for classes and top-level functions marked `@injectable`: how to construct each class (for `Container.make`), its annotations, and its public instance methods with their parameters and annotations, and each function's parameters and annotations. With it, `@Expose` controllers, `@Hooks`/`@Middleware` annotations and `ioc` on `@injectable` functions work without `dart:mirrors`. It no longer depends on `reflectable`, so it resolves with the rest of the Angel3 packages, and the generated code calls constructors without `dart:mirrors` (directly, or with `Function.apply` and symbol literals so that left-out optional parameters keep their defaults), which works in AOT-compiled apps, obfuscated or not
* **Breaking:** Removed `GeneratedReflector`, `ContainedReflectable` and `contained`. To migrate:
  * Replace `@contained` with `@injectable` (from `package:angel3_container`), and add `part '<file>.g.dart';` to each library with such classes
  * Replace `reflectable_builder` with `angel3_container_generator` and `build_runner` in `dev_dependencies`, and run `dart run build_runner build`
  * Replace `GeneratedReflector()` with `StaticReflector.combine([...])`, passing each library's generated variable (e.g. `servicesReflection` for `services.dart`)
* Closures cannot be described: `ioc` on a closure needs an explicit `injection:`, as it did with `GeneratedReflector`

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
