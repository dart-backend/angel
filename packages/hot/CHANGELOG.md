# Change Log

## 10.0.0

### Breaking changes

* **Breaking:** `startServer` throws a `StateError` if called again

### New

* `reload()` reloads on demand, and `hotReload: false` makes the server again without reloading the VM
* `debounce` (default 200 ms) and `shutdownGracePeriod` (default 10 s)
* HTTPS: `securityContext` serves over HTTP/1.1 with `HttpServer.bindSecure`, and `requestClientCertificate` asks clients for a certificate

### Fixes

* **Reloads:** The old server is closed once the new one serves, after the requests it is answering (at most `shutdownGracePeriod`); it used to be never closed, leaking every reload's connections and timers
* **Errors:** A failing `createServer` or reload is logged, and the last good server goes on serving, instead of ending the process. A successful hot reload is no longer reported as failed
* **Concurrency:** File changes are debounced, and reloads run one at a time, with changes during one gathered into the next; `reload()` called meanwhile returns once its reload has run. Requests during a reload wait for it
* **Restart:** `R` makes the server again, instead of adding listeners, watchers and VM connections each time
* **VM service:** The isolate reloaded is this one, and `vmServiceHost` and `vmServicePort` are used when the VM does not tell its URI. Without the VM service, a change still makes the server again
* **`close()`:** Closes the server, the app, the VM connection, the watchers and `stdin`, restores the terminal, answers waiting requests with `503`, and may be called before `startServer`
* **Paths:** A `Glob` watches only its leading directory and matches files created later; watchers are ready before `startServer` returns, and paths of another type are refused by the constructor
* **Logging:** A reload logs to the logger of the server it replaces, and `sendError` sends the status it is given

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.5.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.4.0

* Updated `vm_service` to 15.0.0

## 8.3.1

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
* Updated `vm_service` to 14.0.0
* Fixed linter warnings

## 8.1.0

* Updated `vm_service` to 13.0.0
* Updated README

## 8.0.0

* Require Dart >= 3.0
* Updated `vm_service` to 11.6.0

## 7.0.1

* Updated `server` header to `angel3`

## 7.0.0

* Require Dart >= 2.17
* Updated `vm_service` to 9.3.0

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.3.0

* Updated to use `vm_service` 8.1.0

## 4.2.2

* Fixed '!' operator warning

## 4.2.1

* Fixed license link

## 4.2.0

* Updated to use `belatuk_html_builder` package
* Upgraded to `lints` linter
  
## 4.1.1

* Fixed NNBD issues
* Updated README
  
## 4.1.0

* Updated `vm_service` to 7.1.x

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.0.6

* Support `--observe=*`, `--enable-vm-service=*` (`startsWith`, instead of `==`).

## 2.0.5

* Use `dart:developer` to find the Observatory URI.
* Use the app's logger when necessary.
* Apply `package:pedantic`.

## 2.0.4

* Forcibly close app loggers on shutdown.

## 2.0.3

* Fixed up manual restart.
* Remove stutter on hotkey press.

## 2.0.2

* Fixed for compatibility with `package:angel_websocket@^2.0.0-alpha.5`.

## 2.0.1

* Add import of `package:angel_framework/http.dart`
  * <https://github.com/angel-dart/hot/pull/7>

## 2.0.0

* Update for Dart 2 + Angel 2.

## 1.1.1+1

* Fix a bug that threw when `--observe` was not present.

## 1.1.1

* Disable the observatory from pausing the isolate
on exceptions, because Angel already handles
all exceptions by itself.
