# Angel3 Framework

[![Angel3 Framework](../../assets/branding//angel3_logo.png)](https://github.com/dart-backend/angel)

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_framework?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/framework/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

Angel3 framework is a high-powered HTTP server with support for dependency injection, sophisticated routing, authentication, ORM, graphql etc. It is designed to keep the core minimal but extensible through a series of plugin packages. It won't dictate which features, databases or web templating engine to use. This flexibility enable Angel3 framework to grow with your application as new features can be added to handle the new use cases.

This package is the core package of [Angel3](https://github.com/dart-backend/angel). For more information, visit us at [Angel3 Website](https://angel3-framework.web.app).

## Installation and Setup

### (Option 1) Create a new project by cloning from boilerplate templates

1. Download and install [Dart](https://dart.dev/get-dart)

2. Clone one of the following starter projects:

   * [Angel3 Basic Template](https://github.com/dart-backend/boilerplates/tree/master/templates/basic)
   * [Angel3 PostgreSQL ORM Template](https://github.com/dart-backend/boilerplates/tree/master/templates/basic_postgres_orm)
   * [Angel3 MySQL ORM Template](https://github.com/dart-backend/boilerplates/tree/master/templates/basic_mysql_orm)
   * [Angel3 GraphQL Template](https://github.com/dart-backend/boilerplates/tree/master/templates/basic_graphql)

3. Run the project in development mode (*hot-reloaded* is enabled on file changes).

   ```bash
   dart --observe bin/dev.dart
   ```

4. Run the project in production mode (*hot-reloaded* is disabled).

   ```bash
   dart bin/prod.dart
   ```

5. Run as docker. Edit and build the image with the provided `Dockerfile` file.

### (Option 2) Create a new project with Angel3 CLI

1. Download and install [Dart](https://dart.dev/get-dart)

2. Install the [Angel3 CLI](https://pub.dev/packages/angel3_cli):

   ```bash
   dart pub global activate angel3_cli
   ```

3. On terminal, create a new project:

   ```bash
   angel3 init hello
   ```

4. Run the project in development mode (*hot-reloaded* is enabled on file changes).

   ```bash
   dart --observe bin/dev.dart
   ```

5. Run the project in production mode (*hot-reloaded* is disabled).

   ```bash
   dart bin/prod.dart
   ```

6. Run as docker. Edit and build the image with the provided `Dockerfile` file.

### (Option 3) Add Angel3 to an existing project

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_framework: ^10.0.0
```

## Usage

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

void main() async {
  var app = Angel();

  // Index route. Returns JSON.
  app.get('/', (req, res) => 'Welcome to Angel!');

  // Accepts a URL like /greet/foo or /greet/bob.
  app.get('/greet/:name', (req, res) => 'Hello, ${req.params['name']}!');

  // Simple fallback to throw a 404 on unknown paths.
  app.fallback((req, res) => throw AngelHttpException.notFound());

  var http = AngelHttp(app);
  await http.startServer('127.0.0.1', 3000);
  print('Listening at ${http.uri}');
}
```

See the [example](example/) directory for services, views, error handling and more.

## Running without `dart:mirrors` (AOT)

`dart compile exe` and Flutter do not support `dart:mirrors`. Create the app without a `reflector` and it runs with reflection disabled:

```dart
var app = Angel(); // no MirrorsReflector

app.container.registerSingleton(Greeter());   // register what you inject
app.use('/api/todos', MapService());           // services and hooks work as usual

// Inject with an explicit InjectionRequest instead of reflecting on the closure.
app.get('/greet/:name', ioc(
  (Greeter greeter, String name) => greeter.greet(name),
  injection: InjectionRequest.constant(required: [Greeter, ['name', String]]),
));

// Controllers take their mount path from `expose` and add routes in `configureRoutes`.
class HealthController extends Controller {
  HealthController() : super(expose: const Expose('/health'));

  @override
  void configureRoutes(Routable routable) =>
      routable.get('/', (req, res) => {'status': 'ok'});
}
```

Without reflection, these features are unavailable: `@Expose` on controller methods, the `@Middleware` and `@Hooks` annotations (they are ignored), automatic constructor injection in `container.make`, and `ioc` without `injection:`. See [example/no_mirrors.dart](example/no_mirrors.dart) for a complete app.

To keep them in an AOT-compiled app, mark the classes `@injectable`, generate their reflection data with [`angel3_container_generator`](https://pub.dev/packages/angel3_container_generator), and pass it to the app: `Angel(reflector: StaticReflector.combine([...]))`. On the Dart VM, `MirrorsReflector` of [`angel3_container_mirrors`](https://pub.dev/packages/angel3_container_mirrors) does the same with `dart:mirrors`.

## Request limits

`req.parseBody()` (also used by services) reads at most `app.maxBodySize` bytes, 10 MB by default, and answers larger requests with `413 Payload Too Large`:

```dart
var app = Angel()..maxBodySize = 1024 * 1024; // 1 MB for the whole app

// Allow larger bodies on one route by raising the limit before parsing.
app.post('/upload', uploadHandler, middleware: [
  (req, res) {
    req.maxBodySize = 100 * 1024 * 1024; // 100 MB
    return true;
  },
]);
```

Set `app.maxBodySize = null` to remove the limit. In production, resolved routes are cached per request path; the cache holds at most `app.maxHandlerCacheSize` entries (1024 by default, `0` disables it).

## Available Packages

Angel3 is a collection of packages: pick the ones a project needs. Each is described in its own README.

| Package | Description |
| --- | --- |
| **Core** | |
| [angel3_framework](https://pub.dev/packages/angel3_framework) | The HTTP and HTTP/2 server: routing, services, controllers, middleware and dependency injection |
| [angel3_route](https://pub.dev/packages/angel3_route) | Isomorphic router with route parameters, groups and middleware, also usable in Flutter and the browser |
| [angel3_container](https://pub.dev/packages/angel3_container) | Hierarchical dependency injection container, with pluggable reflection backends |
| [angel3_container_mirrors](https://pub.dev/packages/angel3_container_mirrors) | `MirrorsReflector`, a `dart:mirrors` reflection backend for apps run on the Dart VM (new in 10.0.0) |
| [angel3_container_generator](https://pub.dev/packages/angel3_container_generator) | Generates reflection data for `@injectable` classes, so DI works without `dart:mirrors` (AOT) |
| [angel3_configuration](https://pub.dev/packages/angel3_configuration) | Loads YAML configuration files, per environment, and `.env` files |
| [angel3_http_exception](https://pub.dev/packages/angel3_http_exception) | An HTTP exception that is serialized to JSON for clients |
| **Data and persistence** | |
| [angel3_model](https://pub.dev/packages/angel3_model) | Base data model classes, such as `Model` with an id and timestamps |
| [angel3_serialize](https://pub.dev/packages/angel3_serialize) | Annotations for model serialization |
| [angel3_serialize_generator](https://pub.dev/packages/angel3_serialize_generator) | Generates model classes, `toJson`/`fromMap` serializers and TypeScript definitions |
| [angel3_orm](https://pub.dev/packages/angel3_orm) | ORM runtime: a database-agnostic query builder and the loading of relations |
| [angel3_orm_generator](https://pub.dev/packages/angel3_orm_generator) | Generates the ORM's query classes and migrations from models |
| [angel3_orm_postgres](https://pub.dev/packages/angel3_orm_postgres) | PostgreSQL executor for the ORM, with transactions and savepoints |
| [angel3_orm_mysql](https://pub.dev/packages/angel3_orm_mysql) | MySQL and MariaDB executors for the ORM |
| [angel3_orm_service](https://pub.dev/packages/angel3_orm_service) | A service over the ORM's query classes |
| [angel3_migration](https://pub.dev/packages/angel3_migration) | Schema DSL for database migrations |
| [angel3_migration_runner](https://pub.dev/packages/angel3_migration_runner) | Runs migrations on PostgreSQL, MySQL and MariaDB |
| [angel3_mongo](https://pub.dev/packages/angel3_mongo) | A service backed by MongoDB |
| [angel3_rethinkdb](https://pub.dev/packages/angel3_rethinkdb) | A service backed by RethinkDB, with changefeeds |
| [angel3_sembast](https://pub.dev/packages/angel3_sembast) | A service backed by Sembast, an embedded NoSQL database |
| [angel3_redis](https://pub.dev/packages/angel3_redis) | A service backed by Redis, also usable as a cache |
| [angel3_file_service](https://pub.dev/packages/angel3_file_service) | A service that persists data to a JSON file, for development |
| [angel3_paginate](https://pub.dev/packages/angel3_paginate) | Platform-agnostic pagination of lists |
| **Authentication and security** | |
| [angel3_auth](https://pub.dev/packages/angel3_auth) | Authentication with JWTs, local and Basic strategies |
| [angel3_auth_oauth2](https://pub.dev/packages/angel3_auth_oauth2) | Sign in users with OAuth2 providers, such as Google or GitHub |
| [angel3_auth_twitter](https://github.com/dart-backend/angel/tree/master/packages/auth_twitter) | Sign in users with Twitter OAuth 1.0a (not published) |
| [angel3_oauth2](https://pub.dev/packages/angel3_oauth2) | Building blocks of an OAuth 2.0 authorization server, with PKCE |
| [angel3_security](https://pub.dev/packages/angel3_security) | CSRF protection, signed cookies and rate limiting |
| [angel3_cors](https://pub.dev/packages/angel3_cors) | Cross-Origin Resource Sharing (CORS) middleware |
| **Views and templates** | |
| [jael3](https://pub.dev/packages/jael3) | Jael, a server-side HTML templating engine |
| [jael3_preprocessor](https://pub.dev/packages/jael3_preprocessor) | Resolves the template inheritance and includes of Jael templates |
| [angel3_jael](https://pub.dev/packages/angel3_jael) | Renders Jael templates as Angel3 views |
| [jael3_web](https://github.com/dart-backend/angel/tree/master/packages/jael/jael_web) | Experimental virtual DOM engine built on Jael (not published) |
| [jael3_language_server](https://github.com/dart-backend/angel/tree/master/packages/jael/jael_language_server) | Language Server Protocol implementation for Jael (not published) |
| [angel3_mustache](https://pub.dev/packages/angel3_mustache) | Renders Mustache templates as views |
| [angel3_jinja](https://pub.dev/packages/angel3_jinja) | Renders Jinja templates as views |
| [angel3_markdown](https://pub.dev/packages/angel3_markdown) | Renders Markdown files as views |
| [angel3_html](https://pub.dev/packages/angel3_html) | Sends `belatuk_html_builder` nodes as HTML responses |
| [angel3_seo](https://pub.dev/packages/angel3_seo) | Inlines CSS and JavaScript into HTML pages, for faster first loads |
| **Real time, clients and tools** | |
| [angel3_websocket](https://pub.dev/packages/angel3_websocket) | WebSockets for services and controllers, with browser and `dart:io` clients |
| [angel3_sync](https://pub.dev/packages/angel3_sync) | Synchronizes WebSocket events across instances with `belatuk_pub_sub` |
| [angel3_client](https://pub.dev/packages/angel3_client) | Client for Angel3 services, for the browser, Flutter and the command line |
| [angel3_static](https://pub.dev/packages/angel3_static) | Serves static files, with caching and `Range` requests |
| [angel3_cache](https://pub.dev/packages/angel3_cache) | Response caching middleware, and a caching service |
| [angel3_proxy](https://pub.dev/packages/angel3_proxy) | Forwards requests to another server |
| [angel3_shelf](https://github.com/dart-backend/angel/tree/master/packages/shelf) | Runs `shelf` handlers in Angel3, and Angel3 in `shelf` (not published) |
| [angel3_user_agent](https://pub.dev/packages/angel3_user_agent) | Parses the user agent of requests |
| [angel3_validate](https://pub.dev/packages/angel3_validate) | Validates request bodies and queries, on the server and the client |
| [angel3_hot](https://pub.dev/packages/angel3_hot) | Hot reloading of the server during development |
| [angel3_production](https://pub.dev/packages/angel3_production) | Runs the app in several isolates, with respawning and graceful shutdown |
| [angel3_test](https://pub.dev/packages/angel3_test) | Testing utilities: a client that sends mock requests, and matchers |
| [angel3_mock_request](https://pub.dev/packages/angel3_mock_request) | Mock `dart:io` requests and responses, for tests without a server |

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that need changes in an app:

### `MirrorsReflector` moved to `angel3_container_mirrors`

Add `angel3_container_mirrors` to your dependencies, and change the import:

```dart
// 9.x
import 'package:angel3_container/mirrors.dart';

// 10.0.0
import 'package:angel3_container_mirrors/angel3_container_mirrors.dart';

var app = Angel(reflector: MirrorsReflector());
```

To compile the app with `dart compile exe`, use generated reflection data instead, or no reflector, as [Running without `dart:mirrors`](#running-without-dartmirrors-aot) describes.

### `chain` stops at the first handler that does not return `true`

Like the handlers of a route, each handler given to `chain` must return `true` for the next one to run. A handler that returns nothing, such as a middleware that only sets a value, now stops the chain:

```dart
// 9.x: `handler` ran after it
chain([(req, res) { req.params['user'] = 'me'; }, handler]);

// 10.0.0
chain([(req, res) { req.params['user'] = 'me'; return true; }, handler]);
```

### Buffered responses send `Content-Length`

A buffered response is sent with a `Content-Length` header instead of chunked transfer encoding. Set `res.chunked = true` to send it chunked.

### Default response headers

`AngelHttp.addResponseHeader` and `removeResponseHeader` take a `Map` of headers:

* `addResponseHeader` throws an `ArgumentError` for a header that cannot be sent, before it adds any of the call's headers.
* `removeResponseHeader` removes each value of a list, every value equal to a given one, and, if none matches exactly, those that match ignoring case, such as `sameorigin` for the `SAMEORIGIN` that `dart:io` adds. A `null` value removes the header whatever its values.

```dart
var http = AngelHttp(app);
http.removeResponseHeader({'X-FRAME-OPTIONS': 'SAMEORIGIN'});
http.removeResponseHeader({'X-XSS-PROTECTION': null});
http.addResponseHeader({'X-XSRF-TOKEN': 'a591a6d4...'});
```

### `bool` ids

`Service.parseId<bool>` answers ids other than `true` and `false` with a `400 Bad Request`.

### HTTP/2 sessions

An HTTP/2 request gets a session, and the session cookie, only when `req.session` is first read. Code that expects the cookie on every response must read `req.session`.

## Performance Benchmark

The performance benchmark can be found at

[TechEmpower Framework Benchmarks Round 21](https://www.techempower.com/benchmarks/#section=data-r21&test=composite)

## Donation & Support

If you like this project and interested in supporting its development, you can make a donation using the following services:

* [![GitHub](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/dukefirehawk)
* [paypal](https://paypal.me/dukefirehawk?country.x=MY&locale.x=en_US) service
