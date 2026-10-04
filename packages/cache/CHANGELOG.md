# Change Log

## 9.2.0

* fix: `CacheService.read` now stores a cache miss with `cache.update`, under the requested id.
* fix: `ResponseCache` now stores only responses that are safe to share: status 200, no cookies, and not marked `Cache-Control: no-store` or `private`. Requests with an `Authorization` header bypass the cache. Responses that are not cached no longer get `Cache-Control: public` headers
* fix: `ResponseCache` memory is now bounded by `maxEntries` (default 1024), evicting expired then least recently used entries; previously every distinct URL (including query strings) added an entry and a lock that were never removed
* fix: `CacheService` writes now update (`modify`, `update`) or evict (`remove`) the entry in the shared `cache` service, so other instances using the same cache no longer serve stale or deleted records
* fix: `CacheService.update` now calls `database.update` instead of `database.modify`
* fix: `CacheService.read` no longer throws on params without a `query`, uses the cache for reads without params, and falls back to the database when the cache is unavailable
* feat: Added `ResponseCache(maxEntries: ...)`
* chore: Removed the unused `pool` dependency

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

## 4.0.3

* Updated linter to `package:lints`

## 4.0.2

* Updated README
* Added home page link
* All 7 unit tests passed

## 4.0.1

* Updated pubspec description
* Fixed: Return `200` with cached data instead of `403`
* Updated broken unit tests

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.1

* Add `ignoreQueryAndFragment` to `ResponseCache`.
* Rename `CacheService.ignoreQuery` to `ignoreParams`.

## 1.0.0

* First version
