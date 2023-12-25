# Angel3 Serialize Generator

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_serialize_generator?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/serialize/angel_serialize_generator/LICENSE)

The builder for Angel3 serialization.

## Usage

1. Create a model class in `todo.dart` and annotate it with `@serializable`

    ```dart
        import 'package:angel3_serialize/angel3_serialize.dart';
        part 'todo.g.dart';

        @serializable
        class _Todo {
            String? text;
            bool? completed;
        }
    ```

2. Run the following command to generate the associated `todo.g.dart` file for serialization.

    ```bash
        dart run build_runner build
    ```
