# Change Log

## 10.0.0

### Breaking changes

* **Breaking:** An instance that fails to start ends `run` with exit code 70 (after closing the others), instead of staying alive and serving nothing
* **Breaking:** `InstanceInfo.id` is a non-nullable `int`

### New

* Graceful shutdown on `SIGINT` and `SIGTERM`, and with `Runner.stop()`: each instance stops accepting requests, lets those in progress finish, and runs its shutdown hooks, within the new `shutdownTimeout`. Instances of `spawnIsolate` are stopped too
* The key and certificate passwords may be given in the `ANGEL_KEY_PASSWORD` and `ANGEL_CERTIFICATE_PASSWORD` environment variables, which other users cannot see

### Fixes

* **Logs:** Each record is printed once, with its own level, where every line was formatted twice and shown as `INFO`. The app's logger is set before `configureServer`, so records logged while configuring are printed, and a logger the app sets is kept
* **Respawn:** A crashing instance is respawned after a delay that doubles from 1 s to 30 s, as is one that fails to start again after it has started once, and the ports of each instance are closed when it exits, where they piled up with every respawn
* **Arguments:** An invalid `--port` or `--concurrency` (or one of 0) is a usage error; `--help` is shown before other checks
* **HTTP/2:** `responseHeaders` and `removeResponseHeaders` apply with `--http2` too, and HTTP/1 requests to an `--http2` server are let finish on shutdown

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.5.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.4.1

* Updated `intl` to 0.20.0

## 8.4.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.3.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.2.1

* Updated repository link

## 8.2.0

* Updated `lints` to 3.0.0
* Updated `intl` to 0.19.0
* Fixed linter warnings

## 8.1.0

* Added optional `responseHeaders` and `removeResponseHeaders` to `Runner`

## 8.0.0

* Require Dart >= 3.0

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.0.0

* Skipped release

## 3.1.2

* Updated repo link
* Fixed null safety warnings

## 3.1.1

* Fixed license link

## 3.1.0

* Updated to use `belatuk_pub_sub` package

## 3.0.3

* Upgraded from `pendantic` to `lints` linter

## 3.0.2

* Fixed NNBD issues
* Updated references to `angel3` framework
* Updated README

## 3.0.1

* Fixed static analysis warnings

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD

## 2.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 1.0.0

* Support SSL/HTTP2.
* Support muting the logger via `--quiet`.

## 1.0.0-alpha.1

* Import `framework/http`.

## 1.0.0-alpha

* Initial version.
