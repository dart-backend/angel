# Change Log

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
