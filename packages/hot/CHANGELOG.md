# Change Log

## 10.0.0-beta.1

* fix: The old server is closed on a reload, once the new one serves: its WebSockets, its shutdown hooks, and its app, where it was never closed, as it was read after being cleared, so every reload kept the last app's connections, timers and listeners
* fix: A successful hot reload is no longer reported as failed, and a failed one is, with the VM's notices, where the check was of `success != null`
* fix: A server that `createServer` fails to make, or a reload that fails, is logged, and the last good server goes on serving, where the error was uncaught, and ended the process, or left requests to time out with `502`
* fix: Changes are gathered for the new `debounce` (default 200 ms), and reloads run one at a time, as changes during one trigger one more after it, where every file event reloaded at once, and the reloads overlapped. Requests during a reload wait for the new server, and are then handled at once, not one after another
* fix: Restarting with `R` makes the server again, where it called `startServer` again, which added listeners, file watchers and a connection to the VM service each time, so that a change reloaded once more for each restart. **Breaking:** `startServer` throws a `StateError` if called again
* fix: The isolate reloaded is the one the HotReloader runs in, where it was the first the VM listed. `vmServiceHost` and `vmServicePort` are used if the VM does not tell the URI of its service, where they were not used
* fix: `close()` closes the server and the app, the connection to the VM service, the file watchers and the `stdin` subscription, and gives the terminal back its line and echo modes, and may be called before `startServer`
* feat: `reload()` reloads on demand; `hotReload: false` makes the server again on changes without reloading the VM. Without the VM service, a change makes the server again, where changes were not watched
* fix: `sendError` sends the status it is given. A `Glob` also matches files created after the start. File watchers are ready before `startServer` returns
* feat: `securityContext` serves over HTTPS (HTTP/1.1), with `HttpServer.bindSecure`, and `requestClientCertificate` asks clients for a certificate; the URL printed is `https`
* fix: A server that a reload replaces answers the requests it is answering before it is closed, for at most the new `shutdownGracePeriod` (default 10 s), where its shutdown hooks ran under them
* fix: `close()` answers the requests that wait for a reload with `503`, where their timers later answered them on closed connections; a response that cannot be sent is logged
* fix: `reload()` called during a reload returns once the reload after it, of its changes, has run, where it returned with the one that was running
* fix: A `Glob` watches only the directory of its leading segments without wildcards, where it watched the whole working directory, including `.dart_tool` and `.git`
* fix: Paths of another type are refused by the constructor, where `startServer` threw after making the app. A reload logs to the logger of the server it replaces, where it printed

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
