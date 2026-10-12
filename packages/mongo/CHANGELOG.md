# Change Log

## 10.0.0

* fix!: `modify` of a missing id is now a 404. It used to create a document instead, which over REST could overwrite another one
* fix!: `remove` of a missing id is now a 404, instead of a 200 with `{"id": null}`. `remove('null')` removes the documents matching the query
* feat: `create` now sets `createdAt` and `updatedAt`, and `update` keeps `createdAt`
* fix: `create` now always inserts a new document. With any params, as every REST request has, it upserted on a query matching every document, so each `POST` after the first replaced an existing document
* fix: `create` no longer stores a client-set `_id`, `id`, `createdAt` or `updatedAt`
* fix: `readMany` now returns only the given ids, instead of every document
* fix: `allowQuery: false` now ignores queries from clients; it was never applied
* fix: A malformed id in `update` or `remove` is now a 400, instead of a 500
* fix: Request-context keys are now removed from query maps nested more than one level deep
* fix: `modify` no longer stores an `id` field in the document, and removes one stored by older versions
* docs: `MongoService` does not need reflection: the example and tests now create the app without a reflector, so they no longer use `MirrorsReflector` (which moved from `package:angel3_container/mirrors.dart` to the `angel3_container_mirrors` package)
* docs: The example now starts a server, and the README example compiles
* test: The tests use the server in `MONGO_HOST` (default `localhost`)
* chore: Released with the other Angel3 packages at 10.0.0
* chore: Removed the unused `angel3_container` dependency, and moved `belatuk_json_serializer`, used only by the tests, to `dev_dependencies`

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
