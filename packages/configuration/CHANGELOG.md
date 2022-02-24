# Change Log

## 6.0.0

* Updated to min SDK 2.15.x

## 5.0.0

* No release. Skipped

## 4.1.0

* Updated to use `package:belatuk_merge_map`
* Updated to use `package:belatuk_pretty_logging`
* Updated linter to `package:lints`

## 4.0.1

* Updated README
* All 8 unit tests passed

## 4.0.0

* Migrated to support Dart SDK 2.12.x NNBD

## 3.0.0

* Migrated to work with Dart SDK 2.12.x Non NNBD

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
