# AI Context for Angel3

## Project Overview

**Angel3** is a production-ready, full-stack backend framework in Dart. It originated as a fork of the original Angel framework to support Dart SDK null-safety and later versions. It aims to streamline development by providing many common backend features out-of-the-box and enables developers to build both frontends and backends in Dart. It is highly modular, designed as a collection of plugins.

## Repository Structure

This repository is a **monorepo** organised as a [Dart pub workspace](https://dart.dev/tools/pub/workspaces) and managed with [Melos](https://pub.dev/packages/melos).

- **Packages**: Located in the `packages/` directory. Each package is published to `pub.dev` under the `angel3_` prefix, except the Jael packages (`jael3`, `jael3_preprocessor`, `jael3_web`). Some are grouped one level deeper (e.g. `packages/orm/orm_postgres`, `packages/serialize/serialize_generator`, `packages/jael/jael`). `packages/framework_mirrors_test` is not published (`publish_to: none`): it tests the framework with `MirrorsReflector`.
- **Workspace**: The root `pubspec.yaml` lists every package under `workspace:` and each package declares `resolution: workspace`, so a single `dart pub get` resolves all packages together. New packages must be added to the root `pubspec.yaml` and to `melos.yaml`.
- **Generated code**: `*.g.dart` files produced by `build_runner` (serialization, ORM, migrations, reflection data) are committed and must not be edited by hand. After changing a generator, regenerate the packages whose tests use it (for `orm_generator`: `orm_postgres` and `orm_mysql`). The generated files of `orm_service` predate the current generator, so regenerating them brings in unrelated changes.

## Core Architecture and Packages

The framework is divided into several categories of packages:

1. **Core Framework & Request Handling**:
   - `framework`: Base HTTP and HTTP/2 server, request/response contexts, services, controllers and middleware pipelines.
   - `route`: URL matching and route parameters.
   - `container`: Dependency Injection (DI) system, without `dart:mirrors`. Reflection is pluggable: `container_mirrors` provides the opt-in `MirrorsReflector` (Dart VM only), and `container_generator` generates static reflection data for `@injectable` classes, used through `StaticReflector`, so apps can be compiled with `dart compile exe`. Without a reflector, `@Expose` controller methods, `@Hooks`/`@Middleware` and `ioc` without an explicit `injection:` are unavailable.
   - `configuration`: Loads YAML configuration files and `.env` files.

2. **Data Modeling & Persistence (ORM)**:
   - `model`: Base model abstractions for data entities.
   - `serialize`: JSON serialization and deserialization using code generation (`serialize_generator`). Model classes are named with the `Entity` suffix (`TodoEntity` generates `Todo`); the `_` prefix is still supported.
   - `orm`: Dialect-agnostic ORM runtime (`orm`), code generator (`orm_generator`), schema DSL (`migration`), migration runner (`migration_runner`), database executors for PostgreSQL 14+ (`orm_postgres`) and MySQL 8+/MariaDB 10.2+ (`orm_mysql`, on the `mysql_dart` driver), and an Angel service adapter (`orm_service`). `@HasOne` and `@BelongsTo` are joined; `@HasMany` and `@ManyToMany` are loaded after the records with one query each (`Query.loadRelations`), so a record is one row.
   - `mongo`, `rethinkdb`, `sembast`: Specialized NoSQL database drivers.

3. **Authentication & Security**:
   - `auth`: Core authentication abstractions and strategies.
   - `auth_oauth2`, `oauth2`: OAuth2 authentication flows.
   - `security`: Security middleware: CSRF protection (`CsrfFilter`), signed cookies (`CookieSigner`) and rate limiting.
   - `cors`: Cross-Origin Resource Sharing handling.

4. **Frontend & Template Rendering**:
   - `jael`: Jael template engine built specifically for Angel: parser and renderer (`jael3`), template inheritance (`jael3_preprocessor`), Angel integration (`angel3_jael`) and an experimental virtual DOM (`jael3_web`).
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
- **Monorepo Management**: Dart pub workspace + `melos` (`^8.9.0`)
- **Code Generation**: `build_runner` with `source_gen`-based generators
- **Shared utilities**: The `belatuk_*` packages (e.g. `belatuk_code_buffer`, `belatuk_combinator`, `belatuk_html_builder`, `belatuk_merge_map`, `belatuk_range_header`, `belatuk_symbol_table`) are published from a separate repository. The workspace resolves one version of each dependency for every package, so bump a shared dependency in all the packages that use it at once; one may also require another's new major (`belatuk_combinator` 6 needs `belatuk_code_buffer` 6). Since `belatuk_html_builder` 6, text and attribute values are HTML-escaped when rendered; since `belatuk_code_buffer` 6, `writeln()` with no line open adds a blank line, which renderers that end lines conditionally must allow for (see `jael3`'s `Renderer`).
- **CI**: GitHub Actions (`.github/workflows/dart.yml`) checks only some packages: format, `dart analyze` and `dart test` for `container` and `framework`; format and `dart analyze` for `orm` and `orm_generator`; and the same plus `dart test` for `orm_postgres`, against a PostgreSQL service container. Other packages are not checked by CI, so run their tests locally.

## Development Workflow

- **Master Branch**: Stable production branch (currently the `9.x` releases). Use this branch for all standard PR submissions.
- **Feature Branches**: Work is done on `feature/<name>` branches. The upcoming `10.0.0` release (all packages bumped to `10.0.0`, with breaking changes recorded in each package's `CHANGELOG.md`) is being prepared on feature branches.
- **Tooling**: Run `dart pub get` at the root, or use `melos` to execute tasks across the monorepo (e.g., `melos exec "dart pub upgrade"`). Regenerate code with `dart run build_runner build --delete-conflicting-outputs` in the affected package.
- **Running tests**: Run `dart test` from the package's directory, as some tests read fixtures relative to it (e.g. the `dev.pem` and `dev.key` of `framework`'s HTTP/2 tests). To tell whether a failure is new, run the test with your changes stashed (`git stash push -- packages`, then `dart pub get`); `pubspec.lock` is not tracked, so do not name it in the stash.
- **Database tests**: The tests of these packages need running servers, configured by environment variables:
  - `orm_postgres`: PostgreSQL (`POSTGRES_HOSTNAME`, `POSTGRES_DB`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD`; default `localhost`, `postgres`/`postgres`).
  - `orm_mysql`: MySQL or MariaDB (`MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_DB`, `MYSQL_USERNAME`, `MYSQL_PASSWORD`, `MYSQL_SECURE`; default `localhost:3306`, database `orm_test`, user `test`).
  - `mongo`: MongoDB on port 27017 with a `root` user whose password is `Qwerty` (authentication database `admin`); host `MONGO_HOST`, default `localhost`.
  - `rethinkdb`: RethinkDB on port 28015, user `admin` without a password; host `RETHINKDB_HOST`, default `localhost`. Create its `testDB.todos` table with `dart test/bootstrap.dart`.
  - `redis`: Redis (`REDIS_HOST`, `REDIS_PORT`; default `localhost:6379`).

  Run the ORM tests with `dart test -j1`, as test files share tables.
- **READMEs**: Code samples in a README must compile against the current API (e.g. route handlers take `(req, res)`, `AngelHttp` comes from `package:angel3_framework/http.dart`), and dependency snippets use the current version.
- **Changelog**: Every user-facing change gets an entry in the affected package's `CHANGELOG.md`, written as plain-English statements about the package (not commit messages). Group a release's entries under `### Breaking changes in X.Y.Z` (each entry prefixed `**Breaking:**`), `### New in X.Y.Z` and `### Fixes in X.Y.Z`, in that order, omitting empty sections. Prefix each fix with a bold area label, e.g. `* **Services:** An invalid id is a 400`. See `packages/framework/CHANGELOG.md` (10.0.0) for the reference style. Commit messages use [Conventional Commits](https://www.conventionalcommits.org/) (`type(scope): description`, `!` for breaking changes).

## Key Technical Debt and Future Roadmap

- Removal of dependency on the `dart:mirrors` library: done for 10.0.0. Only `container_mirrors` imports it, as an opt-in `MirrorsReflector`; `framework`, `container`, `websocket`, `jael` and `markdown` no longer use it.
- Performance optimizations to address long-overdue issues.
- Integration of OpenAPI 3 support.
- Expanding ORM support for SQLite, SQL Server, Oracle DB, multi-tenant architectures, and SQL schema reverse engineering.
- ORM caching with Redis.
- Out-of-the-box OIDC and SAML2 support.
