# Change Log

## 10.0.0

* fix: Authentication over a WebSocket refuses an expired JWT, one issued to another IP address when `AngelAuth.enforceIp`, and one whose user does not exist, as `AngelAuth` does over HTTP, where it took any JWT of a valid signature
* fix: A connection from an origin `allowedOrigins` does not allow is refused before it is upgraded, with a `403`, where the socket was upgraded and left open. `allowedProtocols` applies to HTTP/1.1: a connection that asks only for other protocols is refused with a `400`, and the first allowed one it asks for is used
* **Breaking:** WebSockets over HTTP/2 are refused with a `501 Not Implemented`, where the upgrade could not work: HTTP/2 has no `Connection: upgrade`
* fix: The `@ExposeWs` methods of a `WebSocketController`, and its hooks (`onConnect`, `configureWs`, ...), are not HTTP routes, where, with a reflector, `GET /game/search` called the `@ExposeWs` method `search`. Uses the new `Controller.routesMethod` of `angel3_framework`
* fix: A `WebSocketController` finds the `@ExposeWs` methods it inherits from the superclasses the reflector describes (with a `StaticReflector`, those that are `@injectable` too), as it did with `dart:mirrors`, unless it overrides them
* **Breaking:** The streams of `AngelWebSocket`, `WebSocketContext`, the clients and their services are broadcast streams: an event is given to those listening when it comes, and is not kept for those who listen later, where every message was kept until someone listened, without bound. So more than one `WebSocketController` can handle the actions of the same sockets, where the second threw `Stream has already been listened to`. `socket.on[name]` and `client.on[name]` give only the events of the names listened to
* fix: `doNotBroadcast` blocks only the providers it is given, where it blocked the broadcasts of every provider, and it is generic, so that it can be passed to `HookedService.before`, where its type was that of no service
* fix: The client does not reconnect after `close()`, and tries to reconnect one attempt at a time, where attempts every interval could overlap and open more than one socket. `connect` throws the error of the connection, or a `TimeoutException`, where it threw `'Error'`, and sends the actions given before it connects without a timeout too
* fix: The events of the client's `onAllEvents` and `on[...]` keep their names (`todos::created`), where `onServiceEvent` changed them to `created`
* fix: The `dart:io` client uses the `deserializer` of `service`. The services of a client are closed with it, and stop listening when they are closed. `service<Id, Data>` throws an `ArgumentError` that tells to use a nullable `Data` (`service<String, Todo?>`), as a WebSocket service's methods return `null`, where it threw a failed cast
* fix: `batchEvent` sends to a copy of the clients, as one may disconnect while a filter runs. `onClose` of a socket fires when it closes, and its streams are closed. A custom event's data that is not a map, or a missing `id` or `eventName`, no longer fails the action (`"null"`). `send` and `sendError` use the `serializer` of `AngelWebSocket`. The result of a `create`, `modify`, `update` or `remove` of a service that does not broadcast its events is sent to the socket
* fix: `authenticateViaPopup` of the browser client removes its listener of the window when it ends
* fix: A `WebSocketController` listens to the actions and data of a socket before `onConnect` runs, and handles those that come meanwhile once it has, where they were lost, as its streams are broadcast streams. An error of `onConnect` is sent to the socket
* fix: `connect` of a connected client returns its socket, where it opened a second one, whose events came twice. The data of a socket that has closed is ignored, where its closed streams threw
* fix: Authentication when `allowAuth` is `false` is refused with `403 Authentication over WebSockets is disabled.`, where it was reported as `No JWT provided for authentication.`
* fix: A subclass of `AngelWebSocket` can be configured: it is registered as its own type and as `AngelWebSocket`, where `configureServer` threw `This container already has a singleton for AngelWebSocket`
* test: `websocket_test.dart`
* **Breaking:** `angel3_websocket` no longer uses `dart:mirrors`, so a server that uses it can be compiled with `dart compile exe`. The `@ExposeWs` methods of a `WebSocketController` are found through the app's reflector, as the `@Expose` routes of a `Controller` are, so they need one that reflects upon the controller: a `StaticReflector` of the data `angel3_container_generator` generates for it (`Angel(reflector: StaticReflector.combine([...]))`), which works with `dart compile exe`, or `MirrorsReflector` of `angel3_container_mirrors`; with the default `ThrowingReflector` none is found. Without reflection, register a handler with the new `exposeWs(eventName, (action, socket) => ...)`, in the new `configureWs`, which is used in place of an `@ExposeWs` method of the same event name. See the README
* test: The controller tests run an `@ExposeWs` controller with a `StaticReflector` of the reflection data `angel3_container_generator` generates for it (`test/controller/common.g.dart`, regenerated with `dart run build_runner build`), and one of `exposeWs` with the default `ThrowingReflector`. No test uses `dart:mirrors`

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.5.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.4.0

* Removed deprecated `dart:html`
* Refactored the code to use `package:web`

## 8.3.0

* Require Dart >= 3.6
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
