# Change Log

## 10.0.0

* fix: A multipart body cut off before its closing boundary is now a 400; the request used to hang for good, waiting for the last part to end
* fix: A multipart part with a malformed `Content-Disposition` is now a 400 instead of a 500
* fix: `MapService.update` no longer adds `created_at: null` to a record that had no created-at field, as `modify` already did
* fix: `q=0` written after a tab (e.g. `gzip;\tq=0`) now rejects that encoding or media type, like one written after a space
* fix: A hostname pattern with a trailing dot (the FQDN form, `example.com.`) matches the hostname without it again, as it did before `|` patterns were rewritten
* fix: Response compression now treats `Accept-Encoding: gzip;Q=0` (capital `Q`) as rejecting gzip, as parameter names ignore case; it used to compress with gzip anyway
* fix: `RequestContext.accepts` no longer rejects a type because a variant of it with other parameters has `q=0`; `text/html;level=1;q=0, text/html` now accepts `text/html`
* fix: A buffered HTTP/2 response now sets the `DARTSESSID` cookie for a session first created by a response finalizer; the cookie used to be added before the finalizers ran, so such a session was lost
* fix: An HTTP/2 request that fails before reaching a handler (e.g. no `:path`) no longer holds back the rest of its body with the stream paused, which stalled the stream's flow control until the connection closed
* fix: An optional or named handler parameter is left unresolved only when its type cannot be constructed (no usable constructor, or an abstract class); an error thrown while constructing it now fails the request instead of being swallowed
* fix: `MapService.update` (`PUT`) now replaces the record in place, as `modify` (`PATCH`) does, instead of moving it to the end of `items`, so the order of records is kept
* fix: The default error page now labels its UTF-8 body `charset=utf-8` instead of `charset=utf8`, which is not a registered charset name, so Dart clients such as `package:http` decoded the page as Latin-1
* fix: A typed route parameter (e.g. `/n/int:id`) given text that is not a number no longer matches the route (404, or the next matching route), instead of failing with 400 error.
* fix: Middleware passed to `app.group(...)` now runs; previously it was ignored, so a group guarded by middleware (e.g. authentication) was served without it.
* fix: HTTP/2 sessions are now created only when `req.session` is first read, instead of for every request without a `DARTSESSID` cookie, which let any client fill the session store. **Behaviour change:** responses that never use the session no longer set a `DARTSESSID` cookie
* feat: Added `Http2RequestContext.hasSession` to check for a session without creating one
* fix: `ResponseContext.done` now completes when the response is closed (or with the first error passed to `addError`), instead of never completing
* fix: `res.redirectTo()` without `params` no longer fails with a null check error
* fix: Services with non-String ids (e.g. `int`) mounted with `app.use` now receive parsed ids; previously every REST request by id failed with a 500 error. An id of `null` or one that cannot be parsed now returns 400
* fix: `Service.parseId` now parses nullable types (e.g. `int?`) like their non-nullable form, and throws a `FormatException` for a `null` id when the type cannot hold `'null'`, instead of a `TypeError`
* fix: An HTTP/1.1 response with an invalid header that bypasses validation (e.g. via `headers.putIfAbsent`) and no body now fails with 500 error, instead of never being sent
* fix: An HTTP/1 request that cannot become a `RequestContext` (e.g. repeated `X-HTTP-Method-Override` headers) now returns 400 error, instead of terminating the server process. This also applies to `AngelHttp.handleRequest` on a server created outside of `startServer`
* fix: An HTTP/1 request with an invalid `Content-Type` (e.g. `foo`) is now treated as `text/plain`, instead of terminating the server process
* feat: Added `Driver.handleRawRequestSafely`, which answers 400 when a request fails before it reaches the app
* fix: HTTP/2 buffered responses (`res.useBuffer()`) are now sent with their status, headers and body, instead of the stream being reset with no response.
* fix: HTTP/2 error fallbacks (e.g. the 400 for a request that cannot be handled) now send their status, instead of resetting the stream
* fix: HTTP/2 server pushes now send their status and headers; previously a pushed response had a body but no headers
* fix: With `allowHttp1: false` (and no `onHttp1` listener), `AngelHttp2` now closes HTTP/1 connections, instead of leaving them hanging and keeping them in memory
* fix: `app.shutdownHooks` now run when the server is closed, before services are closed; previously they never ran. Services are closed even if a hook fails, and the hook's error is then rethrown from `close()`
* fix: Subclasses of `Angel` (e.g. `BaseAngelClient`) can now be constructed, instead of throwing `StateError: This container already has a singleton for Angel`. The app is registered in the container under its own type and as `Angel`
* fix: After-modify hook listeners now receive a `modified` event, instead of `created`; WebSocket clients were sent `::created` for every modify
* fix: `HookedService.fire` now passes its `result` to listeners, instead of `null`
* fix: Canceling a `remove` in a before hook on a typed `HookedService` now returns the cancel result, instead of failing with a `TypeError`
* fix: Buffered HTTP/1 responses now work for HTTP/1.0 clients (e.g. nginx's default `proxy_pass`), instead of failing. **Behaviour change:** buffered responses are now sent with `Content-Length` instead of chunked encoding, unless `res.chunked` is set to `true`
* fix: Named parameters of DI handlers (`ioc`, controllers) that have a default value and cannot be resolved are now left out, so the default applies, instead of being passed `null` (which failed with a `TypeError` for non-nullable parameters). Other unresolved named parameters (e.g. `required String? q`) are still passed `null`. This needs to know which parameters have defaults: `MirrorsReflector` reports it, as does `GeneratedReflector` with `contained`; for an `InjectionRequest` written by hand, list them in `namedWithDefaults`. Otherwise unresolved named parameters are passed `null`, as before
* feat: Added `InjectionRequest.namedWithDefaults`, the named parameters left out when they cannot be resolved
* fix: `@Header`, `@Query`, `@CookieValue` and `@Session` parameters of any type (not only `String` and numbers) now read their value, instead of being made by the container
* fix: Optional positional and named DI parameters whose type is not registered in the container, and cannot be constructed (e.g. an abstract class), now receive `null`, instead of failing the request
* fix: Controllers with getters, setters, static or private methods can now be mounted; those members are no longer treated as routes. Declarations without a function (e.g. fields listed by a reflector) are skipped too
* fix: `MapService` now returns copies of its records, so changing a result (e.g. removing a field in an after hook) no longer changes the stored record
* fix: Concurrent `modify`, `update` and `remove` calls on the same `MapService` record no longer fail with a 404
* fix: `MapService.modify` no longer lets the data change `id` or `created_at` when `autoIdAndDateFields` is on; previously a PATCH could give two records the same id
* fix: `MapService.update` with `autoIdAndDateFields` off now keeps the record's id when the data has none, instead of making the record unreachable
* fix: A `parseBody` call made while the body is being parsed now waits for that parse, instead of returning before the body is available. After a failed parse, later calls fail with the same error, instead of succeeding with an empty body; `hasParsedBody` is `true` only once parsing has succeeded
* fix: Multipart uploads with a filename and a text `Content-Type` (e.g. `text/csv`, `application/json`) are now in `uploadedFiles` with their original bytes, instead of being decoded into `bodyAsMap`
* feat: Added `UploadedFile(formData, contentType: ...)` to report a `Content-Type` other than the part's
* fix: `MapService` with `autoIdAndDateFields` off now matches non-string ids by their string form, so a record with `id: 1` is found by `'1'` (as REST requests send it)
* fix: `res.jsonp` now rejects a callback name that is not a plain (optionally dotted) identifier with 400 error, instead of writing it into the script, and awaits an async `serializer`
* fix: Responses from an app with `encoders` now send `Vary: Accept-Encoding`. A body that already has a `content-encoding` header (e.g. a precompressed file) is no longer compressed again, and 204 and 304 responses are no longer compressed
* fix: `chain` now stops at a handler that does not return `true`, like a route's own handlers, instead of running the remaining handlers. **Behaviour change:** a handler in a `chain` that returns nothing now ends the chain
* fix: Hostname patterns with `|` (e.g. `example.com|api.example.com`) now match any of the whole hostnames, instead of throwing a `FormatException`
* fix: `findService` now finds a service mounted after an earlier lookup of the same path failed
* fix: `Service.parseId<bool>` now throws a `FormatException` (400 over REST) for ids other than `true` and `false`, instead of returning `false`. **Behaviour change**
* fix: When a before hook cancels a call without a result, `HookedService.index` now returns an empty list, and other methods of a service whose `Data` is not nullable throw a `StateError` explaining the problem, instead of a `TypeError`. A canceled `index` may return a list of any element type
* fix: `MapService` now sorts missing values last for descending `$sort` too
* fix: `res.writeCharCode` now writes the character as UTF-8, instead of a single (truncated) byte
* fix: A malformed `application/x-www-form-urlencoded` body (e.g. invalid percent-encoding) or a multipart part without `Content-Disposition` is now a 400 error, instead of 500
* fix: `req.accepts` now honours a type or `type/*` rejected with `q=0` when a wildcard is also present (e.g. `text/html;q=0, */*`). `ResponseContext.selectEncoder` matches encodings case-insensitively, and `*` no longer picks an encoding rejected with `q=0`
* fix: HTTP/2 request bodies are now read only as fast as the handler consumes them (using HTTP/2 flow control), so an unread or slowly read body is no longer buffered in memory. A body the handler does not read is discarded once the request is closed
* fix: HTTP/2 trailers no longer change the request's path, host or headers, and a request without `:method` or `:path` is now a 400 error
* fix: HTTP/2 responses now use `app.serializer`, like HTTP/1
* fix: `AngelHttp.uri` now uses `https` for servers created with `AngelHttp.secure` or `AngelHttp.fromSecurityContext`

## 9.2.0

* feat: Services, hooked services and `@Middleware` lookups now work without reflection; annotations are ignored when no reflector is configured instead of throwing an errror. This enabled support for `dart compile exe` to be used to build applications without reflection.
* feat: Added `Controller(expose: ...)` to set the mount path without using reflection through `@Expose` annotation
* feat: Added `ioc(..., injection: InjectionRequest)` for dependency injection without using reflection
* feat: Added session timeout (default 20 minutes), idle HTTP/2 sessions are now discarded instead of being kept forever
* feat: Added max size to the content body and rejects larger body with 413 error. The default limit is 10 MB
* feat: Finalizers now run at most once per response
* feat: Added max route cache size (default 1024); the production route cache now evicts least recently used entries.
* feat: Added `ResponseContext.attachmentDisposition()` and `Driver.closeServer()`
* fix: An empty JSON array (`[]`) in the POST request body no longer causing a 500 errer
* fix: `_http` is now nullable and only closed if it was created.
* fix: The default error handler now HTML-escapes the exception message and errors (XSS)
* fix: `res.redirect()` now escapes the URL in the HTML fallback page and no longer emits `javascript:`, `vbscript:` or `data:` (XSS)
* fix: `HookedService.afterAllStream()` now emits after-events instead of before-events
* fix: A missing `@CookieValue` now uses its `defaultValue` or returns 400, instead of a 500 error
* fix: `DELETE /` on a service now requests "remove all" (id `'null'`), subject to `allowRemoveAll`; services with non-String ids return 405 instead of a 500 error
* fix: An HTTP/2 request with a malformed header value (e.g. a bare `%`) no longer crashes the server process
* fix: HTTP/2 header values are no longer percent-decoded or split on commas
* fix: `req.hostname` over HTTP/2 now comes from the `:authority` header instead of always being `localhost`
* fix: HTTP/2 sessions are now reused across multiple requests via the `DARTSESSID` cookie. Unknown session ids get a new session instead of being adopted
* fix: Errors raised while creating a request context, or on an HTTP/2 connection, are now logged instead of terminating the server
* fix: `HostnameRouter` now passes route parameters (e.g. `:id`) to the sub-app's handlers
* fix: `HostnameRouter` creates each lazily-built app once, even when several requests arrive before creation finishes
* fix: `res.streamFile()` with a response encoder (e.g. gzip) no longer sends the uncompressed `Content-Length`, which crashed the server process
* fix: Unbuffered responses with several `write()` calls are now compressed as one gzip/deflate stream instead of one per write
* fix: Response encoders now skip encodings the client marks `q=0` in `Accept-Encoding`
* fix: HTTP/2 server pushes are no longer compressed without a `content-encoding` header
* fix: A failure while closing an HTTP/1.1 response is now logged instead of terminating the server
* fix: `responseFinalizers` now run on unbuffered responses, just before headers are sent, so they can set headers, status and cookies. They still run after the handler, with the full body, on buffered responses. **Behaviour change:** finalizers that read `res.buffer` should check `res.isBuffered`
* fix: An invalid response header (e.g. a non-ASCII value) now fails with 500 error, thrown where the header is set
* fix: The HTTP/2 `DARTSESSID` session cookie is now `Secure` and `HttpOnly`
* fix: The future returned by `handleRequest`/`handleRawRequest` now completes after the error response is sent when a handler throws an error, instead of never completing
* fix: The `no reflector` startup message is now logged at `info` instead of `warning` as it is not longer a mandatory requirement to use Angel3
* fix: When nothing matches, the driver now returns 404 instead of 500
* fix: The application and default logger now prints their record only once. Creating an app with a custom logger, or setting `app.logger`, no longer removes the application's own `Logger.root` listeners
* fix: `res.download()` no longer sends the file's server path as the download name, encodes any filename safely (RFC 6266), uses `application/octet-stream` for unknown types instead of crashing, reads the file asynchronously, and returns 404 for a missing file. `res.streamFile()` also returns 404 for a missing file instead of an error that revealed its path
* fix: `startServer` now rethrows the original error (e.g. a `SocketException` when the port is in use) instead of a generic `ArgumentError`, and closes the bound server if a startup hook fails
* fix: `res.addStream()` (and so `res.streamFile()`) on a buffered response now writes into the buffer, instead of sending directly and leaving the buffer empty
* fix: `HEAD` requests are now answered by the matching `GET` route, without a body, when no explicit `HEAD` route exists (RFC 9110), including in `HostnameRouter` sub-apps. **Behaviour change:** such requests previously returned 404 or reached a fallback route
* fix: `req.accepts()` now parses the `Accept` header instead of matching substrings: `application/json` no longer matches `application/json-patch+json`, type wildcards such as `text/*` are honoured, and types marked `q=0` are not accepted
* fix: Controller methods named `put…` and `head…` now map to `PUT` and `HEAD` routes. The verb must be a whole word, so `posts()` or `getter()` are now `GET /posts` and `GET /getter`, not `POST /s` and `GET /ter`
* refactor: With no container passed, it now falls back to the request's container
* refactor: Resolved various issues with `MapService`
* refactor: Consolidated multiple copies of the encoder selection logic

## 9.1.1

* Updated README with new links to templates

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.6.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.5.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated `mime` to 2.0.0
* Fixed res.json() will cause 'Bad state: Cannot modify a closed response.' error.

## 8.4.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.3.2

* Updated README

## 8.3.1

* Updated repository link

## 8.3.0

* Updated `lints` to 3.0.0
* Fixed linter warnings

## 8.2.0

* Add `addResponseHeader` to `AngelHttp` to add headers to HTTP default response
* Add `removeResponseHeader` to `AngelHttp` to remove headers from HTTP default response

## 8.1.1

* Updated broken image on README

## 8.1.0

* Updated `uuid` to 4.0.0

## 8.0.0

* Require Dart >= 3.0
* Updated `http` to 1.0.0

## 7.0.4

* Updated `Expose` fields to non-nullable
* Updated `Controller` to use non-nullable field

## 7.0.3

* Fixed issue #83. Allow Http request to return null headers instead of throwing an exception.

## 7.0.2

* Added performance benchmark to README

## 7.0.1

* Fixed `BytesBuilder` warnings

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16
* Updated `container` to non nullable
* Updated `angel` to non nullable
* Updated `logger` to non nullable
* Refactored error handler

## 5.0.0

* Skipped release

## 4.2.4

* Fixed issue 48. Log not working in development

## 4.2.3

* Fixed `res.json()` throwing bad state exception

## 4.2.2

* Added `Date` to response header
* Updated `Server: Angel3` response header

## 4.2.1

* Updated `package:angel3_container`

## 4.2.0

* Updated to `package:belatuk_combinator`
* Updated to `package:belatuk_merge_map`
* Updated linter to `package:lints`

## 4.1.3

* Updated README

## 4.1.2

* Updated README
* Fixed NNBD issues
  
## 4.1.1

* Updated link to `Angel3` home page
* Fixed pedantic warnings

## 4.1.0

* Replaced `http_server` with `belatuk_http_server`

## 4.0.4

* Fixed response returning incorrect status code

## 4.0.3

* Fixed "Primitive after parsed param injection" test case
* Fixed "Cannot remove all unless explicitly set" test case
* Fixed "null" test case

## 4.0.2

* Updated README

## 4.0.1

* Updated README

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.1.1

* `AngelHttp.uri` now returns an empty `Uri` if the server is not listening.

## 2.1.0

* This release was originally planned to be `2.0.5`, but it adds several features, and has
therefore been bumped to `2.1.0`.
* Fix a new (did not appear before 2.6/2.7) type error causing compilation to fail.
<https://github.com/angel-dart/framework/issues/249>

## 2.0.5-beta

* Make `@Expose()` in `Controller` optional. <https://github.com/angel-dart/angel/issues/107>
* Add `allowHttp1` to `AngelHttp2` constructors. <https://github.com/angel-dart/angel/issues/108>
* Add `deserializeBody` and `decodeBody` to `RequestContext`. <https://github.com/angel-dart/angel/issues/109>
* Add `HostnameRouter`, which allows for routing based on hostname. <https://github.com/angel-dart/angel/issues/110>
* Default to using `ThrowingReflector`, instead of `EmptyReflector`. This will give a more descriptive
error when trying to use controllers, etc. without reflection enabled.
* `mountController` returns the mounted controller.

## 2.0.4+1

* Run `Controller.configureRoutes` before mounting `@Expose` routes.
* Make `Controller.configureServer` always return a `Future`.

## 2.0.4

* Prepare for Dart SDK change to `Stream<List<int>>` that are now
  `Stream<Uint8List>`.
* Accept any content type if accept header is missing. See
[this PR](https://github.com/angel-dart/framework/pull/239).

## 2.0.3

* Patch up a bug caused by an upstream change to Dart's stream semantics.
See more: <https://github.com/angel-dart/angel/issues/106#issuecomment-499564485>

## 2.0.2+1

* Fix a bug in the implementation of `Controller.applyRoutes`.

## 2.0.2

* Make `ResponseContext` *explicitly* implement `StreamConsumer` (though technically it already did???)
* Split `Controller.configureServer` to create `Controller.applyRoutes`.

## 2.0.1

* Tracked down a bug in `Driver.runPipeline` that allowed fallback
handlers to run, even after the response was closed.
* Add `RequestContext.shutdownHooks`.
* Call `RequestContext.close` in `Driver.sendResponse`.
* AngelConfigurer is now `FutureOr<void>`, instead of just `FutureOr`.
* Use a `Container.has<Stopwatch>` check in `Driver.sendResponse`.
* Remove unnecessary `new` and `const`.

## 2.0.0

* Angel 2! :angel: :rocket:

## 2.0.0-rc.10

* Fix an error that prevented `AngelHttp2.custom` from working properly.
* Add `startSharedHttp2`.

## 2.0.0-rc.9

* Fix some bugs in the `HookedService` implementation that skipped
the outputs of `before` events.

## 2.0.0-rc.8

* Fix `MapService` flaw where clients could remove all records, even if `allowRemoveAll` were `false`.

## 2.0.0-rc.7

* `AnonymousService` can override `readData`.
* `Service.map` now overrides `readData`.
* `HookedService.readData` forwards to `inner`.

## 2.0.0-rc.6

* Make `redirect` and `download` methods asynchronous.

## 2.0.0-rc.5

* Make `serializer` `FutureOr<String> Function(Object)`.
* Make `ResponseContext.serialize` return `Future<bool>`.

## 2.0.0-rc.4

* Support resolution of asynchronous injections in controllers and `ioc`.
* Inject `RequestContext` and `ResponseContext` into requests.

## 2.0.0-rc.3

* `MapService.modify` was not actually modifying items.

## 2.0.0-rc.2

* Fixes Pub analyzer lints (see `angel_route@3.0.6`)

## 2.0.0-rc.1

* Fix logic error that allowed content to be written to streaming responses after `close` was closed.

## 2.0.0-rc.0

* Log a warning when no `reflector` is provided.
* Add `AngelEnvironment` class.
  * Add `Angel.environment`.
  * Deprecated `app.isProduction` in favor of `app.environment.isProduction`.
* Allow setting of `bodyAsObject`, `bodyAsMap`, or `bodyAsList` **exactly once**.
* Resolve named singletons in `resolveInjection`.
* Fix a bug where `Service.parseId<double>` would attempt to parse an `int`.
* Replace as Data cast in Service.dart with a method that throws a 400 on error.

## 2.0.0-alpha.24

* Add `AngelEnv` class to `core`.
* Deprecate `Angel.isProduction`, in favor of `AngelEnv`.

## 2.0.0-alpha.23

* `ResponseContext.render` sets `charset` to `utf8` in `contentType`.

## 2.0.0-alpha.22

* Update pipeline handling mechanism, and inject a `MiddlewarePipelineIterator`.
  * This allows routes to know where in the resolution process they exist, at runtime.

## 2.0.0-alpha.21

* Update for `angel_route@3.0.4` compatibility.
* Add `readAsBytes` and `readAsString` to `UploadedFile`.
* URI-decode path components in HTTP2.

## 2.0.0-alpha.20

* Inject the `MiddlewarePipeline` into requests.

## 2.0.0-alpha.19

* `parseBody` checks for null content type, and throws a `400` if none was given.
* Add `ResponseContext.contentLength`.
* Update `streamFile` to set content length, and also to work on `HEAD` requests.

## 2.0.0-alpha.18

* Upgrade `http2` dependency.
* Upgrade `uuid` dependency.
* Fixed a bug that prevented body parsing from ever completing with `http2`.
* Add `Providers.hashCode`.

## 2.0.0-alpha.17

* Revert the migration to `lumberjack` for now. In the future, when it's more
stable, there'll be a conversion, perhaps.

## 2.0.0-alpha.16

* Use `package:lumberjack` for logging.

## 2.0.0-alpha.15

* Remove dependency on `body_parser`.
* `RequestContext` now exposes a `Stream<List<int>> get body` getter.
  * Calling `RequestContext.parseBody()` parses its contents.
  * Added `bodyAsMap`, `bodyAsList`, `bodyAsObject`, and `uploadedFiles` to `RequestContext`.
  * Removed `Angel.keepRawRequestBuffers` and anything that had to do with buffering request bodies.

## 2.0.0-alpha.14

* Patch `HttpResponseContext._openStream` to send content-length.

## 2.0.0-alpha.13

* Fixed a logic error in `HttpResponseContext` that prevented status codes from being sent.

## 2.0.0-alpha.12

* Remove `ResponseContext.sendFile`.
* Add `Angel.mimeTypeResolver`.
* Fix a bug where an unknown MIME type on `streamFile` would return a 500.

## 2.0.0-alpha.11

* Add `readMany` to `Service`.
* Allow `ResponseContext.redirect` to take a `Uri`.
* Add `Angel.mountController`.
* Add `Angel.findServiceOf`.
* Roll in HTTP/2. See `pkg:angel_framework/http2.dart`.

## 2.0.0-alpha.10

* All calls to `Service.parseId` are now affixed with the `<Id>` argument.
* Added `uri` getter to `AngelHttp`.
* The default for `parseQuery` now wraps query parameters in `Map<String, dynamic>.from`.
  This resolves a bug in `package:angel_validate`.

## 2.0.0-alpha.9

* Add `Service.map`.

## 2.0.0-alpha.8

* No longer export HTTP-specific code from `angel_framework.dart`.
  An import of `import 'package:angel_framework/http.dart';` will be necessary in most cases now.

## 2.0.0-alpha.7

* Force a tigher contract on services. They now must return `Data` on all
  methods except for `index`, which returns a `List<Data>`.

## 2.0.0-alpha.6

* Allow passing a custom `Container` to `handleContained` and co.

## 2.0.0-alpha.5

* `MapService` methods now explicitly return `Map<String, dynamic>`.

## 2.0.0-alpha.4

* Renamed `waterfall` to `chain`.
* Renamed `Routable.service` to `Routable.findService`.
  * Also `Routable.findHookedService`.

## 2.0.0-alpha.3

* Added `<Id, Data>` type parameters to `Service`.
* `HookedService` now follows suit, and takes a third parameter, pointing to the inner service.
* `Routable.use` now uses the generic parameters added to `Service`.
* Added generic usage to `HookedServiceListener`, etc.
* All service methods take `Map<String, dynamic>` as `params` now.

## 2.0.0-alpha.2

* Added `ResponseContext.detach`.

## 2.0.0-alpha.1

* Removed `Angel.injectEncoders`.
* Added `Providers.toJson`.
* Moved `Providers.graphql` to `Providers.graphQL`.
* `Angel.optimizeForProduction` no longer calls `preInject`,
  as it does not need to.
* Rename `ResponseContext.enableBuffer` to `ResponseContext.useBuffer`.

## 2.0.0-alpha

* Removed `random_string` dependency.
* Moved reflection to `package:angel_container`.
* Upgraded `package:file` to `5.0.0`.
* `ResponseContext.sendFile` now uses `package:file`.
* Abandon `ContentType` in favor of `MediaType`.
* Changed view engine to use `Map<String, dynamic>`.
* Remove dependency on `package:json_god` by default.
* Remove dependency on `package:dart2_constant`.
* Moved `lib/hooks.dart` into `package:angel_hooks`.
* Moved `TypedService` into `package:angel_typed_service`.
* Completely removed the `AngelBase` class.
* Removed all `@deprecated` symbols.
* `Service.toId` was renamed to `Service.parseId`; it also now uses its
  single type argument to determine how to parse a value. \* In addition, this method was also made `static`.
* `RequestContext` and `ResponseContext` are now generic, and take a
  single type argument pointing to the underlying request/response type,
  respectively.
* `RequestContext.io` and `ResponseContext.io` are now permanently
  gone.
* `HttpRequestContextImpl` and `HttpResponseContextImpl` were renamed to
  `HttpRequestContext` and `HttpResponseContext`.
* Lazy-parsing request bodies is now the default; `Angel.lazyParseBodies` was replaced
  with `Angel.eagerParseRequestBodies`.
* `Angel.storeOriginalBuffer` -> `Angel.storeRawRequestBuffers`.
* The methods `lazyBody`, `lazyFiles`, and `lazyOriginalBuffer` on `ResponseContext` were all
  replaced with `parseBody`, `parseUploadedFiles`, and `parseRawRequestBuffer`, respectively.
* Removed the synchronous equivalents of the above methods (`body`, `files`, and `originalBuffer`),
  as well as `query`.
* Removed `Angel.injections` and `RequestContext.injections`.
* Removed `Angel.inject` and `RequestContext.inject`.
* Removed a dependency on `package:pool`, which also meant removing `AngelHttp.throttle`.
* Remove the `RequestMiddleware` typedef; from now on, one should use `ResponseContext.end`
  exclusively to close responses.
* `waterfall` will now only accept `RequestHandler`.
* `Routable`, and all of its subclasses, now extend `Router<RequestHandler>`, and therefore only
  take routes in the form of `FutureOr myFunc(RequestContext, ResponseContext res)`.
* `@Middleware` now takes an `Iterable` of `RequestHandler`s.
* `@Expose.path` now *must* be a `String`, not just any `Pattern`.
* `@Expose.middleware` now takes `Iterable<RequestHandler>`, instead of just `List`.
* `createDynamicHandler` was renamed to `ioc`, and is now used to run IoC-aware handlers in a
  type-safe manner.
* `RequestContext.params` is now a `Map<String, dynamic>`, rather than just a `Map`.
* Removed `RequestContext.grab`.
* Removed `RequestContext.properties`.
* Removed the defunct `debug` property where it still existed.
* `Routable.use` now only accepts a `Service`.
* Removed `Angel.createZoneForRequest`.
* Removed `Angel.defaultZoneCreator`.
* Added all flags to the `Angel` constructor, ex. `Angel.eagerParseBodies`.
* Fix a bug where synchronous errors in `handleRequest` would not be caught.
* `AngelHttp.useZone` now defaults to `false`.
* `ResponseContext` now starts in streaming mode by default; the response buffer is opt-in,
  as in many cases it is unnecessary and slows down response time.
* `ResponseContext.streaming` was replaced by `ResponseContext.isBuffered`.
* Made `LockableBytesBuilder` public.
* Removed the now-obsolete `ResponseContext.willCloseItself`.
* Removed `ResponseContext.dispose`.
* Removed the now-obsolete `ResponseContext.end`.
* Removed the now-obsolete `ResponseContext.releaseCorrespondingRequest`.
* `preInject` now takes a `Reflector` as its second argument.
* `Angel.reflector` defaults to `const EmptyReflector()`, disabling
  reflection out-of-the-box.
