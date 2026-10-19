# Change Log

## 10.0.0

* **Breaking:** `jael3` no longer uses `dart:mirrors`, so a program that renders templates can be compiled with `dart compile exe`. `{{ a.b }}` reads `b` of the `memberResolver` given to `Renderer.render`, if it knows it, or else of a key of a `Map`, a common member of a core type (`length`, `first`, `join`, `toUpperCase`, `toInt`, `year`, ...), or a key of the value's `toJson()`. A getter of another class, which was read through `dart:mirrors`, is read only through `memberResolver` or `toJson()`: give the values of a template as maps, or with `toJson()` (as `@serializable` models have), or a `memberResolver`; `angel3_jael` gives one of the app's reflector. See the README
* fix: `{{ user.name }}` reads the key `name` of a `Map`, where it threw `NoSuchMethodError: Class '_Map<String, String>' has no instance getter 'name'`
* **Breaking:** Removed `new` and `NewExpression`, which could not be used: `new` was scanned as a name, so `{{ new Foo() }}` failed with `Missing closing "}}" in interpolation`, and a named constructor could not be called. `TokenType.$new` is removed, and `new` is a name, as any other. Put a function that makes the value in the scope instead

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.3.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
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

* Fixed analyze errors

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.2.0

* Updated to use `package:belatuk_code_buffer`

## 4.1.0

* Updated to use `package:belatuk_symbol_table`
* Updated linter to `package:lints`

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.2

* Fixed handling of `if` in non-strict mode.
* Roll `JaelFormatter` and `jaelfmt`.

## 2.0.1

* Fixed bug where the `textarea` name check would never return `true`.

## 2.0.0+1

* Meta-update for Pub score.

## 2.0.0

* Dart 2 updates.
* Remove usage of `package:dart2_constant`.

## 1.0.6+1

* Ensure `<element>` passes attributes.

## 1.0.6

* Add `index-as` to `for-each`.
* Support registering + rendering custom elements.
* Improve handling of booleans in non-strict mode.

## 1.0.5

* Add support for DSX, a port of JSX to Dart.

## 1.0.4

* Skip HTML comments in free text.

## 1.0.3

* Fix a scanner bug that prevented proper parsing of HTML nodes
followed by free text.
* Don't trim `<textarea>` content.

## 1.0.2

* Use `package:dart2_constant`.
* Upgrade `package:symbol_table`.
* Added `Renderer.errorDocument`.

## 1.0.1

* Reworked the scanner; thereby fixing an extremely pesky bug
that prevented successful parsing of Jael files containing
JavaScript.
