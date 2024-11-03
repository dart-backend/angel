# Change Log

## 8.3.0

* Require Dart >= 3.5
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0
* Updated `web_socket_channel` to 3.0.0

## 8.1.1

* Updated repository link

## 8.1.0

* Updated `lints` to 3.0.0
* Fixed linter warnings
* Updated `web_socket_channel` to versions below 2.4.1 temporarily. Starting with 2.4.1, its dependency on `dart:html` has been changed to `package:web` which requires a code refactoring to resolve.

## 8.0.0

* Require Dart >= 3.0

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.2

* Updated `package:angel3_container`

## 4.1.1

* Fixed issue with type casting
* Changed `app` parameter of `AngelWebSocket` to non-nullable

## 4.1.0

* Updated `package:belatuk_merge_map`
* Updated linter to `package:lints`

## 4.0.1

* Updated README
* Fixed authentication unit test
* Fixed NNBD issues
* All 3 unit tests passed

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.3

* Remove `WebSocketController.plugin`.
* Remove any unawaited futures.

## 2.0.2

* Update `stream_channel` to `2.0.0`.
* Use `angel_framework^@2.0.0-rc.0`.

## 2.0.1

* Add `reconnectOnClose` and `reconnectinterval` parameters in top-level `WebSockets` constructors.
* Close `WebSocketExtraneousEventHandler`.
* Add onAuthenticated to server-side.

## 2.0.0

* Update to work with `client@2.0.0`.

## 2.0.0-alpha.8

* Support for WebSockets over HTTP/2 (though in practice this doesn't often happen, if ever).

## 2.0.0-alpha.7

* Replace `WebSocketSynchronizer` with `StreamChannel<WebSocketEvent>`.

## 2.0.0-alpha.6

* Explicit import of `import 'package:http/io_client.dart' as http;`

## 2.0.0-alpha.5

* Update `http` dependency.

## 2.0.0-alpha.4

* Remove `package:json_god`.
* Make `WebSocketContext` take any `StreamChannel`.
* Strong typing updates.

## 2.0.0-alpha.3

* Directly import Angel HTTP.

## 2.0.0-alpha.2

* Updated for the next version of `angel_client`.

## 2.0.0-alpha.1

* Refactorings for updated Angel 2 versions.
* Remove `package:dart2_constant`.

## 2.0.0-alpha

* Depend on Dart 2 and Angel 2.

## 1.1.2

* Dart 2 updates.
* Added `handleClient`, which is nice for external implementations
that plug into `AngelWebSocket`.

## 1.1.1

* Deprecated `unwrap`.
* Service streams now pump out `e.data`, rather than the actual event.

## 1.1.0+1

* Added `unwrap`.
