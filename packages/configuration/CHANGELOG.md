# Change Log

## 8.4.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.1.1

* Updated repository link

## 8.1.0

* Updated `lints` to 3.0.0

## 8.0.0

* Require Dart >= 3.0

## 7.0.0

* Require Dart >= 2.17
* Updated `dotenv` to 4.0.x

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Updated to use `package:belatuk_merge_map`
* Updated to use `package:belatuk_pretty_logging`
* Updated linter to `package:lints`

## 4.0.1

* Updated README
* All 8 unit tests passed

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.2.0

* Allow including one configuration within another.
* Badly-formatted `.env` files will no longer issue a warning,
but instead throw an exception.

## 2.1.0

* Add `loadStandaloneConfiguration`.

## 2.0.0

* Use Angel 2.

## 1.2.0-rc.0

* Removed the `Configuration` class.
* Removed the `ConfigurationTransformer` class.
* Use `Map` casting to prevent runtime cast errors.

## 1.1.0 (Retroactive changelog)

* Use `package:file`.

## 1.0.5

* Now using `package:merge_map` to merge configurations. Resolves
[#5](https://github.com/angel-dart/configuration/issues/5).
* You can now specify a custom `envPath`.
