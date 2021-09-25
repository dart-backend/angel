# Change Log

## 3.1.0

* Updated to use `package:belatuk_merge_map`
* Updated to use `package:belatuk_json_serializer`
* Updated linter to `package:lints`

## 3.0.0

* Migrated to support Dart SDK 2.12.x NNBD

## 2.0.3

* Add null-coalescing check when processing queries: <https://github.com/angel-dart/mongo/pull/12>

## 2.0.2

* Fix flaw where clients could remove all records, even if `allowRemoveAll` were `false`.

## 2.0.1

* Override `readMany` and `findOne`.

## 2.0.0-

* Delete `mongo_service_typed`.
* Update for Angel 2.
