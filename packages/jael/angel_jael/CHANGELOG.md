# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** A view is resolved relative to its own directory, where it was the views directory, so that the `extend` and `include` tags of a view in a subdirectory are read relative to it, as those of its parents are, with `jael3_preprocessor` 10
* **Breaking:** Requires `belatuk_code_buffer` 6 and `belatuk_symbol_table` 6, whose `CodeBuffer` a `createBuffer` returns

### New in 10.0.0

* `jael` reads the members of values through the app's reflector (`reflectorMemberResolver`): with a `StaticReflector` of `angel3_container_generator` data, the fields, getters and methods of `@injectable` classes, without `dart:mirrors`; with a `MirrorsReflector`, those of any class. A `memberResolver` it is given is asked first

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

## 6.0.1

* Updated `jael3`
* Updated `jael_preprocessor`

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.3.1

* Removed debug message

## 4.3.0

* Added `jaelTemplatePreload` to preload all JAEL templates into a cache

## 4.2.3

* Turned on generated HTML minification by default

## 4.2.2

* Turned on JAEL template caching by default

## 4.2.1

* Added `minified` parameter for generating minified HTML output

## 4.2.0

* Updated to use `package:belatuk_code_buffer`

## 4.1.0

* Updated to use `package:belatuk_symbol_table`
* Updated linter to `package:lints`

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.0

* Angel 2 and Dart 2 updates.
* Default to `.jael` instead of `.jl`.

## 1.0.3

* Update for annoying map casting bug.

## 1.0.2

* Update for DSX support.
* Clear the buffer on errors.

## 1.0.1

* Use `Renderer.errorDocument`.
