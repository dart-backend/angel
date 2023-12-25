# Angel3 Container Generator

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_container_generator?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/container/angel3_container_generator/LICENSE)

An alternative container for Angel3 that uses `reflectable` package instead of `dart:mirrors` for reflection. However, `reflectable` has more limited relfection capabilities when compared to `dart:mirrors`.

## Usage

* Annotable the class with `@contained`.
* Run `dart run build_runner build <Your class directory>`
* Alternatively create a `build.xml` file with the following content

    ```yaml
    targets:
    $default:
        builders:
        reflectable:
            generate_for:
            - bin/**_controller.dart
            options:
            formatted: true
    ```

## Known limitation

* `analyser` 6.x is not supported due to `reflectable`
* Reflection on functions/closures is not supported
* Reflection on private declarations is not supported
* Reflection on generic type is not supported
