# 2.0.0
* Migrated to work with Dart SDK 2.12.x NNBD

## 1.0.4
* Added `context` to `SymbolTable`.

## 1.0.3
* Converted `Visibility` into a `Comparable` class.
* Renamed `add` -> `create`,  `put` -> `assign`, and `allVariablesOfVisibility` -> `allVariablesWithVisibility`.
* Added tests for `Visibility` comparing, and `depth`.
* Added `uniqueName()` to `SymbolTable`.
* Fixed a typo in `remove` that would have prevented it from working correctly.

## 1.0.2
* Added `depth` to `SymbolTable`.
* Added `symbolTable` to `Variable`.
* Deprecated the redundant `Constant` class.
* Deprecated `Variable.markAsPrivate()`.
* Added the `Visibility` enumerator.
* Added the field `visibility` to `Variable`.