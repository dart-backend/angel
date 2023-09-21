# Change Log

## 8.1.0

* Updated to `uuid`

## 8.0.0

* Require Dart >= 3.0

## 7.0.0

* Require Dart >= 2.17

## 6.0.1

* Fixed AngelHttpException error
* [Breaking] Renamed `error` to `authError` for `AuthorizationException`

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.1

* Updated README

## 4.1.0

* Updated linter to `package:lints`

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.3.0

* Remove `implicitGrant`, and inline it into `requestAuthorizationCode`.

## 2.2.0+1

* Parse+verify client for `authorization_code`.

## 2.2.0

* Pass `client` to `exchangeAuthorizationCodeForToken`.
* Apply `package:pedantic`.

## 2.1.0

* Updates
* Support `device_code` grants.
* Add support for [PKCE](https://tools.ietf.org/html/rfc7636).

## 2.0.0

* Angel 2 support.

## 1.0.0+1

* Dart2 updates + backwards compatibility assurance.
