# AI Context for Angel3

## Project Overview

**Angel3** is a production-ready, full-stack backend framework in Dart. It originated as a fork of the original Angel framework to support Dart SDK null-safety and later versions. It aims to streamline development by providing many common backend features out-of-the-box and enables developers to build both frontends and backends in Dart. It is highly modular, designed as a collection of plugins.

## Repository Structure

This repository is a **monorepo** organised as a [Dart pub workspace](https://dart.dev/tools/pub/workspaces) and managed with [Melos](https://pub.dev/packages/melos).

- **Packages**: Located in the `packages/` directory. Each package is published to `pub.dev` under the `angel3_` prefix. Some are grouped one level deeper (e.g. `packages/orm/orm_postgres`, `packages/serialize/serialize_generator`, `packages/jael/jael`).
- **Workspace**: The root `pubspec.yaml` lists every package under `workspace:` and each package declares `resolution: workspace`, so a single `dart pub get` resolves all packages together. New packages must be added to the root `pubspec.yaml` and to `melos.yaml`.
- **Generated code**: `*.g.dart` files produced by `build_runner` (serialization, ORM, migrations) are committed and must not be edited by hand.

## Core Architecture and Packages

The framework is divided into several categories of packages:

1. **Core Framework & Request Handling**:
   - `framework`: Base HTTP and HTTP/2 server, request/response contexts, services, controllers and middleware pipelines.
   - `route`: URL matching and route parameters.
   - `container`: Dependency Injection (DI) system, with mirrors-based and generated (`container_generator`) reflectors.
   - `configuration`: Utilities for loading config files (YAML, JSON, .env).

2. **Data Modeling & Persistence (ORM)**:
   - `model`: Base model abstractions for data entities.
   - `serialize`: JSON serialization and deserialization using code generation (`serialize_generator`).
   - `orm`: Dialect-agnostic ORM runtime (`orm`), code generator (`orm_generator`), schema DSL (`migration`), migration runner (`migration_runner`), database executors for PostgreSQL (`orm_postgres`) and MySQL/MariaDB (`orm_mysql`), and an Angel service adapter (`orm_service`).
   - `mongo`, `rethinkdb`, `sembast`: Specialized NoSQL database drivers.

3. **Authentication & Security**:
   - `auth`: Core authentication abstractions and strategies.
   - `auth_oauth2`, `oauth2`: OAuth2 authentication flows.
   - `security`: Security middleware (rate limiting, standard headers).
   - `cors`: Cross-Origin Resource Sharing handling.

4. **Frontend & Template Rendering**:
   - `jael`: Jael template engine built specifically for Angel.
   - `mustache`, `jinja`, `markdown`: Template integrations.
   - `html`, `seo`: Utilities for HTML responses and search engine optimization.

5. **Utilities**:
   - `websocket`: Real-time bidirectional communication.
   - `client`: Client-side library to interface directly with Angel3 backends.
   - `cache`, `redis`: Caching interfaces.
   - `hot`, `production`: Hot-reloading tooling and production load management.
   - `test`, `mock_request`: Testing utilities.
   - `shelf`, `proxy`, `static`, `file_service`, `paginate`, `validate`, `sync`, `user_agent`, `http_exception`: Supporting integrations and helpers.

## Technology Stack & Requirements

- **Language**: Dart
- **Minimum SDK Version**: `>=3.13.0 <4.0.0`
- **Monorepo Management**: Dart pub workspace + `melos` (`^8.1.0`)
- **Code Generation**: `build_runner` with `source_gen`-based generators
- **CI**: GitHub Actions (`.github/workflows/dart.yml`) runs format check, `dart analyze` and `dart test` per package; ORM tests run against a PostgreSQL service container

## Development Workflow

- **Master Branch**: Stable production branch (currently the `9.x` releases). Use this branch for all standard PR submissions.
- **Feature Branches**: Work is done on `feature/<name>` branches. The upcoming `10.0.0` release (all packages bumped to `10.0.0`, with breaking changes recorded in each package's `CHANGELOG.md`) is being prepared on feature branches.
- **Tooling**: Run `dart pub get` at the root, or use `melos` to execute tasks across the monorepo (e.g., `melos exec "dart pub upgrade"`). Regenerate code with `dart run build_runner build --delete-conflicting-outputs` in the affected package.
- **Changelog**: Every user-facing change gets an entry in the affected package's `CHANGELOG.md`; breaking changes are marked `**Breaking:**`.

## Key Technical Debt and Future Roadmap

- Removal of dependency on the `dart:mirrors` library (`framework` and `container` no longer import it; `MirrorsReflector` is opt-in via `container_mirrors`. Still imported by `websocket`, `jael`, `migration_runner` and `serialize_generator`).
- Performance optimizations to address long-overdue issues.
- Integration of OpenAPI 3 support.
- Expanding ORM support for SQLite, SQL Server, Oracle DB, multi-tenant architectures, and SQL schema reverse engineering.
- ORM caching with Redis.
- Out-of-the-box OIDC and SAML2 support.
