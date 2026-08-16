# Angel3 Framework

[![Angel3 Framework](assets/branding/angel3_logo.png)](https://github.com/dart-backend/angel)

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
* ORM support for PostgreSQL and MySQL
* MongoDB, Sembast and RethinkDB as storage
* Redis as cache

## The Core Framework

The `packages` directory contains specialized sub-packages that act as individual plugins or modules. Depending on the needs of a project, a developer can plug in specific packages.

They can broadly be categorized as follows:

1. Core Framework & Request Handling
   * framework: The foundational package (angel3_framework). It provides the base HTTP server, request/response contexts, dependency injection container, and middleware pipelines.
   * route: The routing engine handling URL matching and route parameters.
   * container: Dependency Injection (DI) system for resolving services.
   * configuration: Utilities for loading configuration files (YAML, JSON, .env).
2. Data Modeling & Persistence (ORM)
   The framework provides an extensive ORM (angel3_orm) ecosystem with generators and database drivers:

   * orm: Houses the main ORM library, code generator (angel_orm_generator), and SQL dialects for MySQL and PostgreSQL.
   * model: Base model abstractions for data entities.
   * serialize: Libraries to serialize/deserialize data to and from JSON using code generation (angel_serialize_generator).
   * mongo, rethinkdb, sembast: Specialized drivers for interacting with MongoDB, RethinkDB, and Sembast (a NoSQL local database).
3. Authentication & Security
   * auth: Core authentication abstractions and strategies (local, token-based).
   * auth_oauth2 & oauth2: Out-of-the-box support for OAuth2 authentication flows.
   * security: Security middleware (rate limiting, standard headers, etc.).
   * cors: Middleware to handle Cross-Origin Resource Sharing effortlessly.
4. Frontend & Template Rendering
   Support for processing and returning HTML views to the client:

   * jael: The Jael template engine specifically built for Angel, capable of HTML manipulation. It is split into language servers, preprocessors, and web renderers.
   * mustache, jinja, markdown: Wrappers/integrations for rendering Mustache templates, Jinja templates, or parsing Markdown into HTML.
   * html & seo: Utilities for building out HTML responses and optimizing for search engines.
5. Additional Utilities and APIs
   * websocket: Integration for real-time bidirectional communication.
   * client: A client-side library designed to interface seamlessly with Angel3 backends directly from Dart/Flutter.
   * cache & redis: Caching interfaces with Redis integration to improve response times.
   * hot & production: Tooling for hot-reloading the server during development, and managing clustering/multi-threading under production loads.
   * test & mock_request: Testing utilities for mocking HTTP requests without spinning up a real server.
   * file_service & static: For serving static assets (images, CSS, JS) efficiently.

## Important Notes

Angel3 packages are published under `angel3_` prefix on pub.dev. These packages have passed all of their respective test suites before going live. The development work are currently focused on:

* Keeping the packages with `angel3_` prefix in sync with Dart SDK releases
  * Remove and replace deprecated classes and methods while keeping it backward compatible
  * Refactor the code to use new language features
* Fix and resolve reported issues
* Performance optimization
* Improve on existing features, unit test, user guide and examples
* Add new features

## Status

### Release Notes (version: 9.0.0)

* Updated `angel3_` packages to Require Dart >= 3.12.0
* Updated to `melos:8.1
* Updated code generator to use `analyzer` 13.0.x

Branch: `master`

* Dart version : 3.12.0 or later.
* Publish      : Refer to all packages with`angel3_` prefix on [pub.dev](https://pub.dev/publishers/dukefirehawk.com/packages).
* Status       : Production
* Notes        : Use this branch for all PR submission

### What is in the pipeline?

* Remove the use of Mirror
* Performance optimization
* Out of the box OIDC and SAML2 support
* Integrated Open API 3 support
* Expand ORM to support
  * SQL Server
  * Oracle DB
  * SQLite

## Installation and Setup

### (Option 1) Create a new project by cloning from boilerplate templates

1. Download and install [Dart](https://dart.dev/get-dart). Minimum 3.11.0.

2. Clone one of the following starter projects:
   * [Angel3 Basic Template](https://github.com/dukefirehawk/boilerplates/tree/angel3-basic)
   * [Angel3 ORM Template](https://github.com/dukefirehawk/boilerplates/tree/angel3-orm)
   * [Angel3 ORM MySQL Template](https://github.com/dukefirehawk/boilerplates/tree/angel3-orm-mysql)
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

7. Next, refer to the [User Guide](https://angel3-docs.dukefirehawk.com/) to learn more about Angel3 framework.

## Performance Testing

Refer to [Angel3 Performance Test Suite](https://github.com/dart-backend/angel3-perf-test) for more information. It is still in early stage, but eventually will contain test cases for running load testing with [Locust](https://locust.io/) on various key features of Angel3 framework. These test cases can serve as a foundation for building performance tests for any applications developed with Angel3 framework.

## Performance Benchmark

An offical performance benchmark can be found at [TechEmpower Framework Benchmarks](https://www.techempower.com/benchmarks/#section=data-r23)

The test cases are build using standard `Angel3 ORM` template for PostgreSQL and MySQL databases. The result are used for improving Angel3 framework with respect to other frameworks. The following test cases will be added in the subsequent update to this benchmark.

1. Cache with Redis
2. Angel3 with MongoDB

## Documentation

Refer to [User Guide](https://angel3-docs.dukefirehawk.com/) for more detailed information on the available features of Angel3 framework.

## Examples

Take various applications at [Examples](https://github.com/dart-backend/angel3-examples) for a spin to get a feel of what Angel3 framework can do.

## Community

Join us on [Discord](https://discord.gg/3X6bxTUdCM).

## Contributing

If you are interested in contributing to Angel3 framework please check out the [Contribution Guide](CONTRIBUTING.md).

### Development Setup

1. Fork [angel](https://github.com/dart-backend/angel) repository

2. Clone the project to local and create a new branch

   ```bash
   git clone https://github.com/<your_repo_name>/angel.git
   git checkout -b feature/<your_branch_name>
   ```

3. Download and install [Dart 3](https://dart.dev/get-dart)

4. Install `melos:7.3`

   ```bash
   dart pub global activate melos
   ```

5. Run `melos exec "dart pub upgrade"` to update all the packages

6. Contribute changes to the desired packages

## Donation & Support

If you like this project and interested in supporting its development work, you are welcome to make a donation via the following links.

* [![GitHub Sponsor](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/dukefirehawk)
* [Paypal Donation](https://paypal.me/dukefirehawk?country.x=MY&locale.x=en_US)

### Paid Support

We offer professional paid support for teams and developers using `Angel3` framework. Our support services are designed to help you build faster, deploy with confidence, and scale reliably, whether you’re just getting started or running the framework in production. The fund collected will go into continued improvements of the framework.

#### What we can help with

* Architecture and best-practice guidance
* Framework setup, configuration, and upgrades
* Debugging runtime, performance, or build issues
* Production readiness (scaling, monitoring, deployment)
* Code reviews and design feedback
* Custom feature guidance and extensions

#### Who this is for

* Teams using or planning to use `Angel3` in production
* Developers who want expert guidance from people who maintain the framework
* Migration from other dart or none dart framework

#### Support options

We offer flexible plans depending on your needs:

* Hourly support for one-off issues
* Monthly retainers for ongoing help
* Consulting sessions for architecture and planning

Support is available via email, chat, and scheduled calls.

#### Why paid support?

Paid support ensures you get reliable, professional assistance when it matters most.

#### Get in touch

If you’re interested in paid support, contact us at [dukefirehawk.apps@gmail.com] with your contact and use cases. We will get back within 24 hours.
