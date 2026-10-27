# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** ETags are quoted and of the file's modification time and size (`"18f3a2b4c10-a"`), as RFC 9110 requires
* **Breaking:** A symbolic link in `source` to a path outside it is not served, unless the new `followLinksOutsideSource` is `true`

### New in 10.0.0

* `sendFile`, the protected method that `serveFile` uses to write a file, which can ignore `Range`; `serveFile`'s overrides still work

### Fixes in 10.0.0

* **Caching:** `If-None-Match` is checked against the file as it is now, and takes precedence over `If-Modified-Since`, which matches to the second; a changed file was answered with `304`. An invalid date is ignored, and a request's `Cache-Control: no-cache` gets the file
* **Ranges:** A suffix range (`bytes=-500`) is the end of the file, an end past the file is clamped, an `If-Range` that no longer matches sends the whole file, overlapping ranges are merged, and a `416` has `Content-Range: bytes */size`
* **Index files:** Served with their own modification time, not the directory's
* **`Accept`:** Matched with `RequestContext.accepts`, so `text/*` and `q=0` work
* **Listing:** Names are HTML-escaped (XSS), in a `<ul>`
* **Paths:** `publicPath` matches whole segments, and an encoded backslash is a 404 instead of a 500 on Windows
* **Deprecated:** The unused `debug` parameter of `CachingVirtualDirectory`
* **Dependencies:** Requires `belatuk_range_header` 7. A range that ends before it starts (`bytes=5-2`), which it refuses to parse, is still a 416

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
* [Breaking] Updated `CacheAccessLevel` to enhanced Enum. Changed `PUBLIC` to `public` and `PRIVATE` to `private`.
* [Breaking] Removed `accessLevelToString` as the functionality is provided by enhanced Enum

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Updated to use `belatuk_range_header` package
* Upgraded from `pendantic` to `lints` linter

## 4.0.2

* Updated README

## 4.0.1

* Fixed NNBD related issues
* Added logging to `VirtualDirectory` and `CachingVirtualDirectory` to capture exception
* Auto detect and change file separator when POSIX file system is used on Windows and vice versa
* Fixed `push_state_test` unit test failure on Windows
* 12/12 unit tests passed

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.1.3+2

* Prepare for upcoming change to File.openRead()

## 2.1.3+1

* Apply control flow lints.

## 2.1.3

* Apply lints.
* Pin to Dart `>=2.0.0 <3.0.0`.
* Use at least version `2.0.0-rc.0` of `angel_framework`.

## 2.1.2+1

* Fix a typo that prevented `Range` requests from working.

## 2.1.2

* Patch support for range+streaming in Caching server.

## 2.1.1

* URI-encode paths in directory listing. This produces correct URL's, always.

## 2.1.0

* Include support for the `Range` header.
* Use MD5 for etags, instead of a weak ETag.

## 2.0.2

* Fixed invalid HTML for directory listings.

## 2.0.1

* Remove use of `sendFile`.
* Add a `p.isWithin` check to ensure that paths do not escape the `source` directory.
* Handle `HEAD` requests.

## 2.0.0

* Upgrade dependencies to Angel 2 + file@5.
* Replace `useStream` with `useBuffer`.
* Remove `package:intl`, just use `HttpDate` instead.

## 1.3.0+1

* Dart 2 fixes.
* Enable optionally writing responses to the buffer instead of streaming.

## 1.3.0

* `pushState` uses `strict` mode when `accepts` is passed.

## 1.3.0-alpha+2

* Added an `accepts` option to `pushState`.
* Added optional directory listings.

## 1.3.0-alpha+1

* ETags once again only encode the first 50 bytes of files. Resolves [#27](https://github.com/angel-dart/static/issues/27).

## 1.3.0-alpha

* Removed file transformers.
* `VirtualDirectory` is no longer an `AngelPlugin`, and instead exposes a `handleRequest` middleware.
* Added `pushState` to `VirtualDirectory`.

## 1.2.5

* Fixed a bug where `onlyInProduction` was not properly adhered to.
* Fixed another bug where `Accept-Encoding` was not properly adhered to.
* Setting `maxAge` to `null` will now prevent a `CachingVirtualDirectory` from sending an `Expires` header.
* Pre-built assets can now be mass-deleted with `VirtualDirectory.cleanFromDisk()`.
Resolves [#22](https://github.com/angel-dart/static/issues/22).

## 1.2.4+1

Fixed a bug where `Accept-Encoding` was not properly adhered to.

## 1.2.4

Fixes <https://github.com/angel-dart/angel/issues/44>.

* MIME types will now default to `application/octet-stream`.
* When `streamToIO` is `true`, the body will only be sent gzipped if the request explicitly allows it.

## 1.2.3

Fixed #40 and #41, which dealt with paths being improperly served when using a
`publicPath`.
