# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `Paginator.current` is a `PaginationResult<T>`, where it was nullable, so `current!` is not needed
* **Breaking:** A `Paginator` paginates a copy of its items, taken when it is created, so later changes to them are not seen, where pages showed them in `data` but not in their indices and `total`
* **Breaking:** A `Paginator` with an `itemsPerPage` less than `1` throws an `ArgumentError`, where it threw an `UnsupportedError` or `ArgumentError` when its pages were read
* **Breaking:** `angel3_framework` is no longer a dependency, as the library does not use it

### Fixes in 10.0.0

* **Paginator:** `canGoForward` is `false` on the last page, and `next` does not go past it, where both went one page beyond it
* **Paginator:** The `endIndex` of a page with no items is `-1`, as its `startIndex` is
* **Paginator:** A lazy `Iterable` is read once, where it was read several times for each page

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

## 8.1.0

* Updated repository link
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

## 3.1.0

* Updated linter to `package:lints`

## 3.0.1

* Updated README

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD

## 2.0.0

* Dart2 + Angel2 update.
  