# Angel3 Framework

[![Angel3 Framework](./logo3.png)](https://github.com/dukefirehawk/angel)

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_framework?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

**A polished, production-ready backend framework in Dart with NNBD support.**

-----

## About

Angel3 is a fork of archived Angel framework to support Dart SDK 2.12.x or later. It is a full-stack Web framework in Dart that aims to streamline development by providing many common features out-of-the-box in a consistent manner. One of the main goal is to enable developers to build both frontend and backend in the same language, Dart. Angel3 framework is designed as a collection of plugins that enable developers to pick and choose the parts needed for their projects. A series of starter templates are also provided for quick start and trial run with Angel3 framework. Visit our [website](<https://angel3-framework.web.app/>) to learn more.

The availabe features in Angel3 includes:

* Static File Handling
* Basic Authentication
* PostgreSQL ORM
* GraphQL
* And much more...

See all the available [`packages`](https://angel3-docs.dukefirehawk.com/packages) for more information.

## Important Notes

The core Angel Framework migration to Angel3 Framework has completed and published under `angel3_` prefix on pub.dev. The migrated packages have passed all the test cases. The development work will now move onto the next phase which is to refactor and to improve on the features for better development and deployment experience.

The status of the code base is as follows:

Branch: `master`

* Dart version : 2.16.x or later.
* Publish      : Yes. Refer to packages with `angel3_` prefix on [pub.dev](https://pub.dev/publishers/dukefirehawk.com/packages).
* Null Safety  : Yes
* Status       : Production
* Notes        : Use this branch for all PR submission

For more details, checkout [Project Status](https://github.com/dukefirehawk/angel/wiki/Project-Status)

## Release Notes

### Release 6.0.0

* Updated all `angel3_` packages to 6.0.0
* Updated all `angel3_` packages to use SDK 2.16.x or later
* Updated ORM to support MariaDB 10.2.x (stable) and MySQL 8.x (beta)
* Updated code generator to use `analyzer` 3.x.x
* Updated exception handling
* Added default logger to generate standardised logging messages
* Added `melos` support
* Removed deprecated API
* [**Breaking**] `error` for `AngelHttpException` is no longer mandatory

## Installation and Setup

### Create a new project by cloning from boilerplate templates

1. Download and install [Dart](https://dart.dev/get-dart)

2. Clone one of the following starter projects:
   * [Basic Template](https://github.com/dukefirehawk/boilerplates/tree/angel3-basic)
   * [ORM for PostgreSQL Template](https://github.com/dukefirehawk/boilerplates/tree/angel3-orm)
   * [ORM for MySQL Template](https://github.com/dukefirehawk/boilerplates/tree/angel3-orm-mysql)
   * [Angel3 Graphql Template](https://github.com/dukefirehawk/boilerplates/tree/angel3-graphql)

3. Run the project in development mode (*hot-reloaded* is enabled on file changes).

   ```bash
   dart --observe bin/dev.dart
   ```

4. Run the project in production mode (*hot-reloaded* is disabled).

   ```bash
   dart bin/prod.dart
   ```

5. Run as docker. Edit and build the image with the provided `Dockerfile` file.

6. Next, refer to the [developer guide](https://angel3-docs.dukefirehawk.com/) to learn more about Angel3 framework.

### Create a new project with Angel3 CLI

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

7. Next, refer to the [developer guide](https://angel3-docs.dukefirehawk.com/) to learn more about Angel3 framework.

### Migrating from Angel to Angel3

Check out [Migrating to Angel3](https://angel3-docs.dukefirehawk.com/migration/angel-2.x.x-to-angel3/migration-guide-3)

## Performance Benchmark

The performance benchmark can be found at

[TechEmpower Framework Benchmarks Round 21](https://www.techempower.com/benchmarks/#section=data-r21&test=composite)

The test cases are build using standard `Angel3 ORM` template. This result will be used for fine-tuning Angel3 framework. The following test cases will be progressively added in the upcoming update to benchmark.

1. Angel3 with MongoDB
2. Angel3 with ORM MySQL
3. Cached queries

## Examples and Documentation

Visit the [User Guide](https://angel3-docs.dukefirehawk.com/) for dozens of guides and resources, including video tutorials, to get up and running as quickly as possible with Angel3 framework.

Examples and complete projects can be found [here](https://github.com/dukefirehawk/angel3-examples).

You can also view the [Angel3 API](http://www.dartdocs.org/documentation/angel_framework/latest).

## Contributing

Interested in contributing to Angel3? See the contribution guide [here](CONTRIBUTING.md).

## Support

If you like this project and want to support the author, you can [donate](https://paypal.me/dukefirehawk?country.x=MY&locale.x=en_US) me via paypal donations service.
