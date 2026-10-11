# Change Log

## 9.2.0

* fix: `MockHttpRequest.write`, `writeAll`, `writeln` and `writeCharCode` now write in the charset of the request's `content-type` header (UTF-8 if it has none), and `MockHttpResponse`'s use the charset of its `content-type` header (its `encoding` if it has none), instead of writing each UTF-16 code unit as one byte (which corrupted any character outside Latin-1)
* fix: **Breaking** `MockHttpRequest.write`, `MockHttpResponse.write` and the methods that use them now throw `ArgumentError` for a character their encoding cannot represent (such as `'☺'` with `latin1`), as `dart:io` does, instead of silently truncating it
* fix: `MockHttpHeaders.contentType` now behaves as in `dart:io`: it is `null` when the header is absent instead of `text/html; charset=utf-8`, setting `null` removes the header instead of setting `text/html`, and setting a value keeps its charset and other parameters instead of storing only the MIME type
* fix: `MockHttpHeaders.contentLength` is now backed by the `content-length` header, as in `dart:io`: it is `-1` when absent (previously `0`), setting it to `-1` removes the header, and setting it after the headers are locked throws `StateError`
* fix: `MockHttpHeaders` now treats `content-length` as `dart:io` does: it holds one value, a later `add` or `set` replaces it, a value that is not all digits throws `HttpException`, and one with 16 or more significant digits throws `HttpException('Content-Length too large')`; when one of several values is invalid, none is stored
* fix: `MockHttpRequest.contentLength` is now its `content-length` header, as in `dart:io`; `close` sets that header to the number of bytes written, unless it was already set, nothing was written, or `chunkedTransferEncoding` is on. Previously it was a separate byte count that could disagree with the header
* fix: `MockHttpResponse.contentLength` is now backed by `headers.contentLength`, as in `dart:io`, instead of being a separate field that ignored `headers.contentLength = ...`; `MockHttpRequest`'s default response now starts at `-1` (no length set) instead of `0`, and the `MockHttpResponse` constructor's `contentLength` is now optional and defaults to `-1`, since passing `0` now sends `content-length: 0`
* fix: `write` and `writeln` on `MockHttpRequest` and `MockHttpResponse` now behave as in `dart:io`: `write('')` and `writeAll([])` add nothing, so they no longer lock the headers; `write(null)` writes `null` instead of nothing; and `writeln` ends the line with `\n` instead of `\r\n`
* change: `MockHttpRequest.write` and `MockHttpResponse.write` work out the encoding at the first write and keep it, as `dart:io` does, so setting `MockHttpResponse.encoding` after writing no longer changes later writes, and `encoding` then reports the encoding the writes use
* fix: `addError` on `MockHttpRequest` and `MockHttpResponse` now delivers the error after bytes added before it, as in `dart:io`, instead of ahead of them
* fix: `MockHttpRequest` and `MockHttpResponse` no longer emit an empty chunk on `close` or `flush` when nothing is buffered, so a request without a body is an empty stream
* fix: `MockHttpRequest.firstWhere`, `lastWhere` and `singleWhere` without `orElse` now throw `StateError` when nothing matches, instead of a null-check error
* fix: `MockHttpHeaders.remove` now removes the header when its last value is removed, as in `dart:io`, instead of leaving an empty value (which `value()` returned as `''` instead of `null`)
* fix: `MockHttpRequest.close` and `MockHttpResponse.close` can be called more than once and return `done`, as in `dart:io`, instead of throwing `Bad state: Future already completed`
* fix: while `addStream` is running on a `MockHttpRequest` or `MockHttpResponse`, `add`, `addError`, `write`, `flush`, `close` and `addStream` now throw `StateError`, as in `dart:io`, instead of letting `close` cut the stream short; `addStream` now completes with the source stream's first error and stops, instead of completing normally
* fix: `MockHttpResponse` now keeps the `statusCode` passed to its constructor, instead of always using 200
* fix: `MockHttpHeaders.date`, `expires` and `ifModifiedSince` now return `null` when the header is absent, as in `dart:io`, instead of the current time (which made every mock request look like a conditional request); setting them to `null` now removes the header instead of setting the current time

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
