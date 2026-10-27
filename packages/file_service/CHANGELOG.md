# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Strings are no longer turned into `DateTime`s as the file is read, which turned any string `DateTime.parse` accepts, such as an id `20240101`, into a date. A `DateTime` given to `create`, `modify` or `update` is stored, and returned, as its ISO 8601 string; convert dates with a `TypedService` or a model's `fromMap`
* **Breaking:** Passing `allowRemoveAll` or `allowQuery` with a `store` that has another value throws an `ArgumentError`, as they are set on the store, where they were ignored
* **Breaking:** `close` closes only a store the service made, not a `store` it is given
* **Breaking:** Values are turned into JSON by `json.encode`, with a `DateTime` as its ISO 8601 string: a value without a `toJson()`, such as a `Uri`, a `toJson()` that throws, a map key that is not a string, and a cycle throw its error, and store nothing, where they were stored as their `toString()`
* **Breaking:** Requires `angel3_framework` 10, whose `MapService` the service keeps its records in

### Fixes in 10.0.0

* **`modify`:** Changes only the given fields, and a missing id is a 404, where it replaced the record, and created a missing one
* **Writes:** A write is no longer lost when another call reads the file between the change and its save, and the service no longer reads the file again after each of its own writes
* **Changes on disk:** The file is read again when its size changes too, and when its modification time goes back, as when it is restored from a backup, where only a newer modification time was noticed. An edit that keeps the size, within the resolution of the file system's times, can still be missed
* **A file that cannot be read:** One that is not a JSON list of objects is a 500, whose logged error names the file, where it was a `FormatException`, which can be reported as a client error
* **Records handed out:** Share no map or list with the stored records, so changing one does not change what is stored, or saved by the next write
* **A failed save:** A save writes a whole copy of the data next to the file, `<file>.tmp`, before it writes the file in place, so that a save cut off as the file is written is restored from the copy by the next call, and a mount, a symlink and the file's permissions stay as they are. Its change is not served, as the file is read again by the next call; so is a change of a store that throws, but not one a 404 or another `AngelHttpException` of the request leaves unchanged
* **Values with a `toJson`:** Are stored as its JSON, as `json.encode` does, where they were stored as their `toString()`
* **`close`:** Waits for the reads and writes in progress, and a call after it fails with a `StateError`; calling it again does nothing more
* **Docs:** The README tells how to install and use the package, and how to migrate from 9.x


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
* Updated repository link

## 8.0.0

* Require Dart >= 3.0

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Upgraded to `lints` linter

## 4.0.2

* Updated README
* Removed redundant code

## 4.0.1

* Updated package description

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.1

* Pass everything through `_jsonifyToSD` when returning responses.

## 2.0.0

* Dart/Angel 2 update.
* Remove `package:dart2_constant`
* Update `package:file` to `^5.0.0`.

## 1.1.2

* Added tests, because tests.

## 1.1.1

* Dart 2 fixes.

## 1.1.0+2

* `create` now uses the underlying store, instead of manually patching

## 1.1.0+1

* Analyzer nitpick for pana

## 1.1.0

* Updated to framework v1.1.x
* Use `package:file`
* Allow a custom `store`
