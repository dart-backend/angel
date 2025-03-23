# Angel3 Framework

[![Angel3 Framework](angel3_logo.png)](https://github.com/dart-backend/angel)

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_framework?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/LICENSE)
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

**A production-ready dart backend framework.**

-----

## About

Angel3 originated from a fork of the archived Angel framework in support of Dart SDK 2.12.x or later. It is a full-stack backend framework in Dart that aims to streamline development by providing many common features out-of-the-box in a consistent manner. The codebase has been completely migrated and refactored to support null safety. One of the main goal is to enable developers to build both frontend and backend in dart language. Angel3 is designed as a collection of plugins that enable developers to pick and choose the parts needed for their projects. A series of starter templates are also provided for quick start and trial run with Angel3. Visit our [website](<https://angel3-framework.web.app/>) to learn more.

The available features in Angel3 includes:

* OAuth2 Authentication
* WebSocket
* HTTP/2
* HTTP Streaming
* GraphQL
* Markdown, Mustache, Jinja and JAEL as Server-Side HTML Rendering
* ORM for PostgreSQL and MySQL
* MongoDB, Sembast and RethinkDB as storage
* Redis as cache

See all of the available [`packages`](https://angel3-docs.dukefirehawk.com/packages) for more information.

## Important Notes

Angel3 packages are published under `angel3_` prefix on pub.dev. These packages have passed all of their respective test suites before going live. The development work are currently focused on:

* Keeping the packages with `angel3_` prefix in sync with Dart SDK releases
  * Remove and replace deprecated classes and methods while keeping it backward compatible
  * Refactor the code to use new language features
* Fix and resolve reported issues
* Performance optimization
* Improve on existing features, unit test, user guide and examples
* Add new features

The status of the project is as follows:

Branch: `master`

* Dart version : 3.6.x or later.
* Publish      : Yes. Refer to packages with `angel3_` prefix on [pub.dev](https://pub.dev/publishers/dukefirehawk.com/packages).
* Null Safety  : Yes
* Status       : Production
* Notes        : Use this branch for all PR submission

For more details, checkout [Project Status](https://github.com/dart-backend/angel/wiki/Project-Status)

## Release Notes

### Release 9.0.0 (Future)

* Performance optimsation
* Update ORM to support more databases

### Release 8.5.0 (Current)

* Updated `angel3_` packages to require dart >= 3.6.0
* Updated dependencies to the latest
* Updated code generator to use `analyzer` 7.x.x
* Deprecated `angel_orm_test`
* Migrated `dart:html` to `package:web`

### Release 8.0.0

* Updated `angel3_` packages to require dart >= 3.0.0
* Updated dependencies to the latest
* Updated code generator to use `analyzer` 6.x.x

### Release 7.0.0

* Updated `angel3_` packages to require dart >= 2.17.x
* Updated dependencies to the latest
* Updated code generator to use `analyzer` 5.x.x
* Fixed ORM issues

### Release 6.0.0

* Updated all `angel3_` packages to require dart >= 2.16.x
* Updated ORM to support MariaDB 10.2.x (stable) and MySQL 8.x (beta)
* Updated code generator to use `analyzer` 3.x.x
* Updated exception handling
* Added default logger to generate standardised logging messages
* Added `melos` support
* Removed deprecated API
* [**Breaking**] `error` for `AngelHttpException` is no longer mandatory

## TODO

* Improve HTTP and ORM performance
* Improve ORM for MySQL
* Add cache support in ORM (using Redis)
* Upgrade and release angel3_oauth2 8.0.0 (5 failed test cases)
* Upgrade and release angel3_auth_twitter 8.0.0 (Migrate to OAuth2)
* Upgrade and release angel3_shelf 8.0.0 (2 failed test cases)

## Installation and Setup

### Create a new project by cloning from boilerplate templates

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

The performance benchmark can be found at [TechEmpower Framework Benchmarks](https://www.techempower.com/benchmarks/#section=data-r22&test=composite&hw=ph)

The test cases are build using standard `Angel3 ORM` template for PostgreSQL and MySQL database. The result are used for fine-tuning Angel3 framework with respect to other frameworks. The following test cases will be added in the upcoming update to the benchmark.

1. Cache with Redis
2. Angel3 with MongoDB

## Examples and Documentation

Please visit our [User Guide](https://angel3-docs.dukefirehawk.com/) and [Examples](https://github.com/dart-backend/angel3-examples) for more detailed information on the available features of Angel3 framework.

## Community

Join us on [Discord](https://discord.gg/3X6bxTUdCM).

## Contributing

If you are interested in contributing to Angel3 framework please check out the [Contribution Guide](CONTRIBUTING.md).

### Development Setup

1. Fork `angel` repository

2. Clone the project to local and create a new branch

   ```bash
   git clone https://github.com/<your_repo_name>/angel.git
   git checkout -b feature/<your_branch_name>
   ```

3. Download and install [Dart 3](https://dart.dev/get-dart)

4. Install `melos` 6.1

   ```bash
   dart pub global activate melos
   ```

5. Run `melos exec "dart pub upgrade"` to update all the packages

6. Make changes to the packages

## Donation & Support

If you like this project and interested in supporting its development work, you are welcome to make a donation via the following links.

* [![GitHub Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/dukefirehawk)
* [Paypal Donation](https://paypal.me/dukefirehawk?country.x=MY&locale.x=en_US)
