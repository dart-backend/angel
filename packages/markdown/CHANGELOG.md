# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** No longer uses `dart:mirrors`, so apps can be compiled with `dart compile exe`. In `{{user.name}}`, each part is read as a key of a `Map` or of the object's `toJson()`, plus list indexes, `length`, `isEmpty`, `isNotEmpty`, `first` and `last`. Other getters (`{{date.year}}`) throw an `ArgumentError`; put such values in the locals. Values read through `toJson()` render as it writes them
* **Breaking:** Values of `{{...}}` are HTML-escaped (an XSS hole when a value came from the request), percent-encoded in Markdown link URLs, and encoded as character references wherever raw HTML could otherwise be changed. A link made unsafe by its values (e.g. `javascript:`) becomes `#`. A bare `{{url}}` is no longer a link; use `<{{url}}>`. Pass `escape: false` to `markdown()` for trusted values
* **Breaking:** A view name that resolves outside the views directory (`../secret`, an absolute path, a symbolic link out of it), and a missing view or views directory, throw a 404 `AngelHttpException` instead of reading the file or throwing `FileSystemException`

### Fixes in 10.0.0

* **Expressions:** `{{user.name}}` resolves `Map` locals; spaces in `{{ title }}` are ignored; a `null` value renders as nothing
* **Errors:** A missing key, a `null` or an object without `toJson()` mid-expression throws an `ArgumentError` naming the expression; an error inside `toJson()` is passed on as it is
* **`toJson()`:** Called once per object in a render, and only its keys are read

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
