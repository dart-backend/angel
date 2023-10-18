# Angel3 Framework

[![Angel3 Framework](../../angel3_logo.png)](https://github.com/dukefirehawk/angel)

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_framework?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/framework/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

Angel3 framework is a high-powered HTTP server with support for dependency injection, sophisticated routing, authentication, ORM, graphql etc. It is designed to keep the core minimal but extensible through a series of plugin packages. It won't dictate which features, databases or web templating engine to use. This flexibility enable Angel3 framework to grow with your application as new features can be added to handle the new use cases.

This package is the core package of [Angel3](https://github.com/dukefirehawk/angel). For more information, visit us at [Angel3 Website](https://angel3-framework.web.app).

## Installation and Setup

### (Option 1) Create a new project by cloning from boilerplate templates

1. Download and install [Dart](https://dart.dev/get-dart)

2. Clone one of the following starter projects:
   * [Angel3 Basic Template](https://github.com/dukefirehawk/boilerplates/tree/v7/angel3-basic)
   * [Angel3 ORM Template](https://github.com/dukefirehawk/boilerplates/tree/v7/angel3-orm)
   * [Angel3 ORM MySQL Template](https://github.com/dukefirehawk/boilerplates/tree/v7/angel3-orm-mysql)
   * [Angel3 Graphql Template](https://github.com/dukefirehawk/boilerplates/tree/v7/angel3-graphql)

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

## Performance Benchmark

The performance benchmark can be found at

[TechEmpower Framework Benchmarks Round 21](https://www.techempower.com/benchmarks/#section=data-r21&test=composite)

### Migrating from Angel to Angel3

Check out [Migrating to Angel3](https://angel3-docs.dukefirehawk.com/migration/angel-2.x.x-to-angel3/migration-guide-3)

## Donation & Support

If you like this project and interested in supporting its development, you can make a donation via [paypal](https://paypal.me/dukefirehawk?country.x=MY&locale.x=en_US) service.
