# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** An instance that fails to start ends `run` with exit code 70, instead of leaving the runner up with nothing serving
* **Breaking:** `InstanceInfo.id` is a non-nullable `int`
* **Breaking:** `Runner.isolateMain` sends the runner's own messages on `RunnerArgs.loggingSendPort`, not `LogRecord`s, and the instance it starts runs until the runner stops it. Start instances with `run` or `spawnIsolate` instead of spawning `isolateMain` with a port of your own

### New in 10.0.0

* Graceful shutdown on `SIGINT`, `SIGTERM` and `Runner.stop()`: requests in progress finish and shutdown hooks run, within `shutdownTimeout`, and the process exits as soon as the instances have closed. It closes the instances of `run` and of `spawnIsolate` alike, and `spawnIsolate` can start instances again afterwards. Called while nothing runs, it makes the next `run` return without starting instances, unless `spawnIsolate` starts one before
* Key and certificate passwords can come from the `ANGEL_KEY_PASSWORD` and `ANGEL_CERTIFICATE_PASSWORD` environment variables

### Fixes in 10.0.0

* **Logs:** Each record is printed once, at its own level and with the time it was logged at, including records logged during `configureServer`. The runner prints the records of every logger, so a listener that `configureServer` adds to print them prints each one twice
* **Respawn:** Crashed instances are respawned with a backoff from 1 s to 30 s, also when their isolate fails to spawn again, and no longer leak ports
* **Arguments:** An invalid `--port` or `--concurrency` is a usage error; `--help` comes before other checks
* **HTTP/2:** `responseHeaders` and `removeResponseHeaders` apply with `--http2` as without it, to HTTP/2 requests and to the HTTP/1 requests it also serves: the added headers are defaults that a handler's own headers replace, and the removed values are removed from the defaults only. A list value is one header of its values, except `Set-Cookie`, whose values are sent one header each. Its HTTP/1 requests finish on shutdown
* **`removeResponseHeaders`:** A list value removes each of its values, where it removed nothing

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
