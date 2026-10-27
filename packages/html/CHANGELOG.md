# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Pages are sent as `text/html; charset=utf-8`, where they were `text/html` without a charset, which browsers could decode as another encoding
* **Breaking:** `enforceAcceptHeader` is a `bool` that defaults to `false`, not a `bool?`
* **Breaking:** Requires `belatuk_html_builder` 6, which HTML-escapes text and attribute values when a page is rendered: a value escaped by hand is escaped twice, and HTML that must be written as it is takes `raw`

### Fixes in 10.0.0

* **Responses:** Once a page is sent, the request ends, where the handlers after it ran on the closed response (e.g. a fallback that throws a 404). The response is closed and its errors handled by the framework
* **Docs:** The README tells how to migrate from 9.x, installs version 10.0.0, tells that a request without an `Accept` header accepts any type, and its example reads the route's `name` parameter
* **Tests:** Expect the doctype the renderer writes, and that a request without an `Accept` header is answered


## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.3.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.2.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.1.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.0.0

* Require Dart >= 3.0
* Updated `lints` to 3.0.0
* Fixed linter warnings
* Updated repository link

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* No release Skipped

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD

## 2.0.0

* Angel 2 + Dart 2 updates.
