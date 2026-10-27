# Angel3 Serialize Generator

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_serialize_generator?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/serialize/serialize_generator/LICENSE)

The builder for generating JSON serialization code for Angel3 framework.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_serialize: ^10.0.0
dev_dependencies:
  angel3_serialize_generator: ^10.0.0
  build_runner: ^2.4.0
```

## Usage

1. Create a model class in `todo.dart` and annotate it with `@serializable` and append `Entity` suffix to the class name.

    ```dart
        import 'package:angel3_serialize/angel3_serialize.dart';
        part 'todo.g.dart';

        @serializable
        class TodoEntity {
            String? text;
            bool? completed;
        }
    ```

2. Run the following command to generate the associated `todo.g.dart` file for serialization.

    ```bash
        dart run build_runner build
    ```

    The generated class is named without the `Entity` suffix (or a `_` prefix): `Todo`, with `TodoSerializer`, `TodoFields` and a `todoSerializer` codec. A class whose name only ends with the letters of the suffix, such as `UserIdentity`, keeps its name.

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **Regenerate** your models with `dart run build_runner build --delete-conflicting-outputs`: generated `hashCode` getters use `Object.hashAll` instead of `hashObjects`.
* **Class names**: a generated class is named by removing a prefix (`_`, `Entity`), then a suffix (`Entity`), matched by case, so `UserIdentity` keeps its name, where it became `UserId`.
* **`includeAnnotations`**: a value that is not a constant instance of a class or enum fails the build.
* **Code that uses the generator's API**: `SerializableFieldMirror.serializer` and `deserializer` are the names of functions, as `String`s, where they were `Symbol`s.
