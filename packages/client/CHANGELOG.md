# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** The streams of the client, its services and `ServiceList` are broadcast streams: events are not kept for later listeners, so memory no longer grows without bound, and `close()` completes without listeners, where it never returned
* **Breaking:** A REST service is a `Service<Id, Data>`, so `service<String, Todo>()` works, where only a nullable type such as `Todo?` did. Its methods return `Data` and throw an `AngelHttpException` on an error, also when its stream has a listener, where they returned `null`
* **Breaking:** Removed `belatuk_json_serializer` and the `type` parameter of `service()`, which needed `dart:mirrors`. Pass a `deserializer` instead, such as `deserializer: (x) => TodoSerializer.fromMap(x as Map)`; without one, a service returns the decoded JSON. Objects sent to the server are encoded with `jsonEncode`, which calls their `toJson()`
* **Breaking:** Removed `RestService`: `Rest.service()` returns a `BaseAngelService`, like the other clients
* **Breaking:** An id is encoded as one segment of the URL path, so `read('a/b')` requests `/todos/a%2Fb`, where it requested `/todos/a/b`, and an id starting with `/` no longer replaces the path of the service. An id is encoded as it is, so pass ids unencoded: an id the caller encoded, such as `a%20b`, is sent as `a%2520b` and is the id `a%20b` on the server. An empty id, `.` and `..` throw an `ArgumentError`, since they would be the URL of the service or be resolved away
* **Breaking:** A list param is sent as one param per value, such as `?tag=a&tag=b`, where it was sent as `?tag=[a, b]`. An empty list throws an `ArgumentError`, since leaving it out would drop a filter. The query of the client's base URL, such as `?key=x`, is kept as it is when params are passed, where it was dropped

### Fixes in 10.0.0

* **Errors:** A JSON body that is not an object no longer hides the server's error, and an error reports the response's status, also when the body has another `status_code`
* **Failures after a successful response:** A failure such as a deserializer error is a 500 instead of the response's 2xx, also when the body is an error with a 2xx `status_code`, and the `AngelHttpException` carries the original error as `error`. The message is that of a `FormatException` the deserializer throws, unless it is empty, or says the response could not be read. When the body is an error, its own message is kept
* **Error responses:** Reported once: a listener of `onIndexed`, `onRead` and the other streams gets only the `AngelHttpException`, without a second error from reading the body
* **`Rest.service`:** Uses the `deserializer` it is given
* **Data that cannot be encoded:** `create`, `modify` and `update` throw an `ArgumentError` naming the `jsonEncode` error, with its stack trace, for an object without a `toJson()`, where they threw a `JsonUnsupportedObjectError`. An error thrown by a `toJson()` is thrown as it is, and a value a `toJson()` returns that cannot be encoded is also an `ArgumentError`
* **Closed clients:** An `authenticate` response that arrives after `close()` is returned, where adding it to the closed `onAuthenticated` threw a `StateError`. A request still being sent when `close()` closes the HTTP client fails as before
* **Closed services:** A response that arrives after the service is closed is returned or thrown, where adding it to the closed stream threw a `StateError`
* **Typed services without a deserializer:** The error says to pass a `deserializer` when the JSON is not a `Data`, and says so when the body of `read`, `create`, `modify`, `update` or `remove` is `null`, where it was an unhandled exception. `index` still skips items deserialized to `null`
* **Error responses that are not JSON:** The `AngelHttpException` has no `error` or stack trace of the internal `FormatException`, and an error response added to a stream has a stack trace
* **Mapped services:** `create` passes on its `params`, and `index` passes on a `null` result, such as from a WebSocket service, where it threw
* **URLs:** No longer end in `?` without params
* **`ServiceList`:** Passes the errors of the service's streams on to `onChange`, where they were uncaught, and `close` cancels its subscriptions to the service
* **Tests:** No longer use `MirrorsReflector`
* **Docs:** The README tells how to install and use the package


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
* Updated error handling

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
* Updated `http` to 1.0.0

## 7.0.0

* Require Dart >= 2.17
  
## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.2.0

* Updated `package:build_runner`
* Updated `package:build_web_compilers`

## 4.1.0

* Updated `package:belatuk_json_serializer`
* Updated linter to `package:lints`

## 4.0.2

* Added logging
* Added unit test for authentication

## 4.0.1

* Updated README
* Refactored NNBD fixes
* Fixed path issue on Windows
* All 13 unit tests passed

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.2

* `_join` previously discarded quer parameters, etc.
* Allow any `Map<String, dynamic>` as body, not just `Map<String, String>`.

## 2.0.1

* Change `BaseAngelClient` constructor to accept `dynamic` instead of `String` for `baseUrl.

## 2.0.0

* Deprecate `basePath` in favor of `baseUrl`.
* `Angel` now extends `http.Client`.
* Deprecate `auth_types`.

## 2.0.0-alpha.2

* Make Service `index` always return `List<Data>`.
* Add `Service.map`.

## 2.0.0-alpha.1

* Refactor `params` to `Map<String, dynamic>`.

## 2.0.0-alpha

* Depend on Dart 2.
* Depend on Angel 2.
* Remove `dart2_constant`.

## 1.2.0+2

* Code cleanup + housekeeping, update to `dart2_constant`, and
ensured build works with `2.0.0-dev.64.1`.

## 1.2.0+1

* Removed a type annotation in `authenticateViaPopup` to prevent breaking with DDC.

## 1.2.0

* `ServiceList` now uses `Equality` from `package:collection` to compare items.
* `Service`s will now add service errors to corresponding streams if there is a listener.

## 1.1.0+3

* `ServiceList` no longer ignores empty `index` events.

## 1.1.0+2

* Updated `ServiceList` to also fire on `index`.

## 1.1.0+1

* Added `ServiceList`.
