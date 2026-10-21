# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `ResponseCache` bypasses requests with cookies, as it does those with `Authorization`, so a page of a session is not served to others; set `cacheRequestsWithCookies` if no cached response depends on cookies
* **Breaking:** `ResponseCache` does not store a response with a `Vary` other than `Accept-Encoding` (one response is kept per path), a `Content-Encoding` set by the handler (it was served to clients that do not accept it), or `Cache-Control: no-cache`; nor a response to `HEAD` (it has no body, and was served to `GET`), or one longer than `maxEntryBytes`

### New in 10.0.0

* `ResponseCache(maxEntryBytes: ...)` (default 1 MB), so the cache holds at most `maxEntries` times it, and `ResponseCache(cacheRequestsWithCookies: ...)`

### Fixes in 10.0.0

* **Cache headers:** `ResponseCache` marks only the responses it stores `Cache-Control: public`, with `Last-Modified` and `Expires`, and keeps a `Cache-Control` the handler set, where it replaced it on the first response. `HEAD` responses are no longer buffered
* **`CacheService` reads:** A read or index that overlaps a write, even one still in progress, no longer stores what it read over the written version, so instances no longer serve it (or a removed record) until the timeout. Ended entries are removed, where one was kept for every record ever read
* **`CacheService.index`:** Returns a copy of the cached list, so a caller changing it does not change it for others
* **`cacheSerializationResults`:** `shouldCache` is asked before a cached result is reused, so a request it refuses gets a fresh one; the timeout counts from after an async `shouldCache`
* **Docs:** A `MapService` used as the cache needs `autoIdAndDateFields: false`, or cached records get ids and dates of their own; responses of cached paths are buffered, not streamed


## 9.2.0

### Behaviour changes in 9.2.0

* `ResponseCache` stores only responses that are safe to share: status 200, no cookies, and not marked `Cache-Control: no-store` or `private`. Requests with an `Authorization` header bypass the cache, and responses that are not cached no longer get `Cache-Control: public` headers
* `ResponseCache.handleRequest` buffers the response on a cache miss, so normal responses are cached without `res.useBuffer()`; only buffered responses were, so most never were
* `ResponseCache` answers `304 Not Modified` (no body) when the client's copy is current, instead of the full body with 200

### New in 9.2.0

* `ResponseCache(maxEntries: ...)`: memory is bounded (default 1024 entries), evicting expired, then least recently used, entries

### Fixes in 9.2.0

* **Memory:** `ResponseCache` no longer keeps an entry and a lock for every distinct URL (including query strings) for ever
* **Responses:** A cached response is sent with `Content-Length`. A client sending back the exact `Last-Modified` value is recognised (dates are compared in whole seconds), and one with an older copy gets the cached response instead of bypassing the cache
* **`CacheService` writes:** `modify` and `update` update, and `remove` evicts, the entry in the shared `cache` service, so other instances no longer serve stale or deleted records; `update` calls `database.update` instead of `database.modify`
* **`CacheService.read`:** Stores a cache miss with `cache.update`, under the requested id; no longer throws on params without a `query`; uses the cache for reads without params; and falls back to the database when the cache is unavailable
* **`cacheSerializationResults`:** Works: results are cached per object across requests, `shouldCache` and `timeout` are honoured, a result is reused only for the same serializer, and async serializers are supported
* **Dependencies:** Removed the unused `pool` and `meta`, and the unused dev dependency `glob`
* **Docs:** The README is up to date
* **Tests:** `cache_test.dart` is deterministic, and two assertions that expected the old behaviour are corrected

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
