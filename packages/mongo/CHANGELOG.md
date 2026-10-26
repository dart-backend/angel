# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `modify` and `remove` of a missing id are a 404, instead of creating a document, or answering `{"id": null}`

### New in 10.0.0

* `create` sets `createdAt` and `updatedAt`, and `update` keeps `createdAt`
* Clients can sort and limit with `$sort` and `$limit` (e.g. `?$sort=-createdAt&$limit=10`)

### Fixes in 10.0.0

* **`create`:** Always inserts a new document (each `POST` after the first replaced one), and ignores client-set `_id`, `id`, `createdAt` and `updatedAt`
* **Queries:** `readMany` returns only the given ids, `allowQuery: false` is applied, the framework's `page` and `token` keys are not filters, and request-context keys are removed from nested queries
* **Ids:** A malformed id in `update` or `remove` is a 400; `modify` no longer stores an `id` field
* **Docs:** The example starts a server and needs no reflector, and the README example compiles
* **Dependencies:** Removed the unused `angel3_container`, and the dev dependency `belatuk_json_serializer`: the tests use `dart:convert`, so they no longer need `dart:mirrors`

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

## 8.2.1

* Updated README
* Updated example to use MongoDB authentication

## 8.2.0

* Require Dart >= 3.3
* Updated `mongo_dart` to 0.10.3
* Updated `lints` to 4.0.0
* Refactored `mongo_service` class
* Refactored test cases

## 8.1.1

* Updated repository link

## 8.1.0

* Updated `lints` to 3.0.0
* Fixed linter warnings

## 8.0.0

* Require Dart >= 3.0
* Upgraded `mongo_dart` to 0.9.3

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.1.0

* Updated to use `package:belatuk_merge_map`
* Updated to use `package:belatuk_json_serializer`
* Updated linter to `package:lints`

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD

## 2.0.3

* Add null-coalescing check when processing queries: <https://github.com/angel-dart/mongo/pull/12>

## 2.0.2

* Fix flaw where clients could remove all records, even if `allowRemoveAll` were `false`.

## 2.0.1

* Override `readMany` and `findOne`.

## 2.0.0-

* Delete `mongo_service_typed`.
* Update for Angel 2.
