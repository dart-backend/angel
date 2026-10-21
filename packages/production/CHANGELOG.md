# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** An instance that fails to start ends `run` with exit code 70, instead of leaving the runner up with nothing serving
* **Breaking:** `InstanceInfo.id` is a non-nullable `int`

### New in 10.0.0

* Graceful shutdown on `SIGINT`, `SIGTERM` and `Runner.stop()`: requests in progress finish and shutdown hooks run, within `shutdownTimeout`
* Key and certificate passwords can come from the `ANGEL_KEY_PASSWORD` and `ANGEL_CERTIFICATE_PASSWORD` environment variables

### Fixes in 10.0.0

* **Logs:** Each record is printed once, at its own level, including records logged during `configureServer`
* **Respawn:** Crashed instances are respawned with a backoff from 1 s to 30 s, and no longer leak ports
* **Arguments:** An invalid `--port` or `--concurrency` is a usage error; `--help` comes before other checks
* **HTTP/2:** `responseHeaders` and `removeResponseHeaders` apply with `--http2`, and its HTTP/1 requests finish on shutdown

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
