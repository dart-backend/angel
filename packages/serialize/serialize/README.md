# Angel3 Serialization

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_serialize?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/serialize/serialize/LICENSE)

The frontend for Angel3 model serialization. See [`Documentation`](https://angel3-docs.dukefirehawk.com/guides/serialization)

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

Annotate a model, whose name ends with `Entity`, in `todo.dart`:

```dart
import 'package:angel3_serialize/angel3_serialize.dart';

part 'todo.g.dart';

@serializable
abstract class TodoEntity {
  String? get text;

  bool? get completed;
}
```

Run `dart run build_runner build`. It generates `Todo`, with `copyWith`, `==` and `toJson`, and `TodoSerializer`:

```dart
var todo = TodoSerializer.fromMap({'text': 'Clean your room', 'completed': false});
print(todo.toJson());
```

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **`Serializers`** is an `enum`, and `Serializable.serializers` a `List<Serializers>`. Replace integer values with the enum's: `0` is `Serializers.map`, `1` is `Serializers.json` and `2` is `Serializers.typescript`.

  ```dart
  // 9.x
  @Serializable(serializers: [0, 1])

  // 10.0.0
  @Serializable(serializers: [Serializers.map, Serializers.json])
  ```

* **`Serializable.includeAnnotations`** is a `List<Object>`.
* **`hashObjects`** is no longer exported, nor `quiver` a dependency. Regenerate your models, which use `Object.hashAll`, and use `Object.hashAll` in your own code.
