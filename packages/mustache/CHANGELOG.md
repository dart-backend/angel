# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** A view name that resolves outside the views directory (`../secret`, an absolute path, a symbolic link out of it), and a missing view, throw a 404 `AngelHttpException` instead of reading the file or throwing `FileSystemException`
* **Breaking:** A partial that resolves outside the partials directory, or does not exist, renders as nothing, as Mustache specifies, instead of reading the file or throwing `FileSystemException`

### Fixes in 10.0.0

* **Partials:** Read without blocking, and found with the paths of the views directory's own file system
* **Production:** Views and partials are kept parsed, so they are not parsed again on each render
* **Docs:** The README tells how to migrate from 9.x


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

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.1.1

* Updated README

## 3.1.0

* Updated linter to `package:lints`

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD
* Replaced `mustache4dart` with `mustache_template`

## 2.0.0

* Angel 2 and Dart 2 support.
