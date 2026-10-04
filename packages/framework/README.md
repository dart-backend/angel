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

## Performance Benchmark

The performance benchmark can be found at

[TechEmpower Framework Benchmarks Round 21](https://www.techempower.com/benchmarks/#section=data-r21&test=composite)

### Migrating from Angel to Angel3

Check out [Migrating to Angel3](https://angel3-docs.dukefirehawk.com/migration/angel-2.x.x-to-angel3/migration-guide-3)

## Donation & Support

If you like this project and interested in supporting its development, you can make a donation using the following services:

* [![GitHub](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/dukefirehawk)
* [paypal](https://paypal.me/dukefirehawk?country.x=MY&locale.x=en_US) service
