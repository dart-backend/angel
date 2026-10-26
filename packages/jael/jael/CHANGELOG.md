# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** No longer uses `dart:mirrors`, so a program that renders templates can be compiled with `dart compile exe`. `{{ a.b }}` reads `b` from the `memberResolver` given to `Renderer.render`, a `Map` key, a common member of a core type, or the value's `toJson()`; other getters need a `memberResolver` or `toJson()`. `angel3_jael` gives one from the app's reflector. See the README
* **Breaking:** Removed `new`, `NewExpression` and `TokenType.$new`, which could never be parsed; put a function that makes the value in the scope instead
* **Breaking:** With `strictResolution: false`, an unknown member, or a member of `null`, is `null`. `readMember` takes `resolver` as a named parameter, and the new `tryReadMember` returns `noMember`

### Fixes in 10.0.0

* **Members:** `{{ user.name }}` reads the key of a `Map`. `toJson()` is called once per value in a render, its own errors are thrown, and one that takes an argument is not called
* **Null safety:** `?.` makes the rest of the chain `null`, as in Dart
* **Operators:** `%` works; `&&` and `||` are added, and like `??` compute their right side only if needed; `=` is no longer an operator
* **Parsing:** Map literals with keys (`{'a': 1}`) and calls with named arguments (`f(x: 1)`) are parsed; a key-value pair's span starts at its key, and `SyntheticIdentifier.span` works
* **Rendering:** The same `SymbolTable` can be rendered again

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
