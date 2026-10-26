# Change Log

## 10.0.0

### New in 10.0.0

* `PubSubSynchronizationChannel(closeTimeout: ...)`, how long `close` waits for the `pub_sub` server

### Fixes in 10.0.0

* **Closing:** Closing the channel's `sink`, as `AngelWebSocket` does on shutdown, closes the channel, which unsubscribes and closes the `pub_sub` client, where they were left open, and completes once they are closed. `close` waits for the server at most the new `closeTimeout` (default 5 s), so a server that is gone does not stop it, and may be called more than once
* **After closing:** Events are no longer published, and events and errors that come late are dropped, where they failed with a `StateError`
* **Errors:** An event without a name is an error of the stream, and the end of the subscription is told on the stream, which then ends
* **Dependencies:** `angel3_framework` is a dev dependency, as only the tests and example use it
* **Docs:** The README example compiles, and serves the WebSocket. `example/main.dart` runs two synchronized instances, where it was a copy of the tests

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

## 4.1.1

* Fixed license link

## 4.1.0

* Updated to use `belatuk_pub_sub` package
* Upgraded from `pendantic` to `lints` linter

## 4.0.0

* Updated to use `angel3` packages
* Published with `angel3` prefix

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD

## 2.0.0

* Dart 2 + Angel 2 updates.
* Extend `StreamChannel`, instead of the defunct `WebSocketSynchronizer`.
