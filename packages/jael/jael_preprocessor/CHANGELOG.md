# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** The parent of an `extend` is read relative to the directory of the template that extends it, and its includes relative to its own directory, as includes are, where they were read relative to the directory the first template was resolved in
* **Breaking:** Requires `jael3` 10
* **Breaking:** Requires `belatuk_code_buffer` 6 and `belatuk_symbol_table` 6

### Fixes in 10.0.0

* **Blocks:** A block nested deeper than the root of a layout, or within the default content of another block, which no template overrides, gets its default content, where it was left as a `<block>` tag in the output
* **Blocks:** A block within an override that has the name of the block it overrides gets its default content, where it recursed forever
* **Errors:** Without an `onError`, an error is thrown as a `JaelError`, and a warning is ignored, where it was a null-check error; a parent template that cannot be read, or has syntax errors, resolves to null, where it threw a null-check error after reporting it; an include that cannot be read, or has syntax errors, is reported to `onError`, where a `FileSystemException` or a null-check error was thrown; and a parent that cannot be read is reported at the template that extends it
* **Cycles:** A template that extends itself, and a file that includes itself, directly or through others, including through both, are reported to `onError`, where they looped or recursed forever
* **Paths:** Parents and includes are read with `Directory.childFile`, so that a file system whose directory URIs have no trailing slash, as `jael_web`'s, finds them
* **Docs:** The README tells how to migrate from 9.x


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
* Updated `file` to 7.0.0

## 7.0.0

* Require Dart >= 2.17

## 6.0.1

* Fixed `jael3` version

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.2.0

* Updated to use `package:belatuk_code_buffer`

## 4.1.0

* Updated to use `package:belatuk_symbol_table`
* Updated linter to `package:lints`

## 4.0.1

* Resolved static analysis warnings

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.1

* Fixed a bug where failed file resolutions would not become proper errors.

## 2.0.0+1

* Homepage update for Pub.

## 2.0.0

* Dart 2 updates.
* Fix a templating bug where multiple inheritance did not work.

## 1.0.0+1

* Minor change to `Patcher` signature for Dart 2 compatibility.
