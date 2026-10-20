# Change Log

## 10.0.0

The mocks now behave as `dart:io`'s `HttpRequest`, `HttpResponse` and `HttpHeaders` do.

### Breaking changes

* **Breaking:** `MockHttpRequest` extends `Stream<Uint8List>`, so its stream methods have the signatures of `dart:io`'s `HttpRequest`
* **Breaking:** `write` throws `ArgumentError` for a character its encoding cannot represent, instead of truncating it

### New

* `MockHttpHeaders.tryParseContentLength`

### Fixes

* **Encoding:** `write` and its relatives use the charset of the `content-type` header (or UTF-8, or the response's `encoding`), chosen at the first write, instead of writing each UTF-16 code unit as a byte. `write('')` adds nothing, `write(null)` writes `null`, and `writeln` ends lines with `\n`
* **Headers:** `contentType`, `contentLength`, `chunkedTransferEncoding`, `date`, `expires` and `ifModifiedSince` are backed by their headers, with `dart:io`'s defaults, parsing and `null` handling. `content-length` holds one validated value. A header is removed with its last value, a `preserveHeaderCase` name is stored lowercase, and locked headers also reject `persistentConnection`, `host` and `port`
* **Content length:** `MockHttpRequest.close` sets `content-length` to the bytes written (unless set, empty or chunked); a response's length starts at `-1`, and the constructor's `contentLength` is optional
* **Streams:** Errors come after the bytes added before them, no empty chunk is emitted on `close` or `flush`, `add([])` does nothing, and `firstWhere`, `lastWhere` and `singleWhere` throw `StateError` when nothing matches
* **`close` and `addStream`:** `close` may be called more than once and returns `done`; during `addStream`, other writes throw `StateError`, and `addStream` completes with the source's first error
* **Responses:** `MockHttpResponse` keeps the `statusCode` it is given, and `bufferOutput` takes effect

## 9.2.0

* fix: `MockHttpHeaders.date`, `expires` and `ifModifiedSince` now return `null` when the header is absent, as in `dart:io`, instead of the current time (which made every mock request look like a conditional request)

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

## 8.0.0

* Require Dart >= 3.0
* Updated `http` to 1.0.0

## 7.0.1

* Fixed `BytesBuilder` warnings

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.0.0

* Skipped release

## 2.1.0

* Updated linter to `package:lints`

## 2.0.2

* Updated README
* Updated test cases

## 2.0.1

* Updated README

## 2.0.0

* Migrated to work with Dart >= 2.12 NNBD

## 1.0.7

* Prepare for upcoming Dart SDK change where `HttpHeaders` methods
`add` and `set` take an additional optional parameter `preserveHeaderCase` (thanks @domesticmouse!).

## 1.0.6

* Prepare for upcoming Dart SDK change whereby `HttpRequest` implements
  `Stream<Uint8List>` rather than `Stream<List<int>>`.

## 1.0.5

* Add `toString` to `MockHttpHeaders`.

## 1.0.4

* Fix for `ifModifiedSince`

## 1.0.3

* Dart2 fixes
* Apparently fix hangs that break Angel tests
