# Angel3 Data Model

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_model?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/model/LICENSE)

The basic data models for ORM used in Angel3 framework.

```dart
import 'package:angel3_model/angel3_model.dart';
```

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_model: ^10.0.0
```

The available data models are:

* `Model` class
  * A basic data model
* `AuditableModel` class
  * A basic data model with audit log feature

## Usage

```dart
import 'package:angel3_model/angel3_model.dart';

class Todo extends Model {
  String? text;

  bool isComplete;

  Todo({
    required String super.id,
    this.text,
    this.isComplete = false,
    super.createdAt,
    super.updatedAt,
  });
}

void main() {
  var todo = Todo(id: '34');
  print(todo.idAsInt == 34); // true
}
```

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **`none`** is an instance of `None` (`const None()`), so `none is None` is true. Compare types with `None`, as `T == none` is now false:

  ```dart
  // 9.x
  if (T == none) { ... }

  // 10.0.0
  if (T == None) { ... }
  ```

* **`None`** is a `final class` with a `const` constructor, and every `None` equals `none`, which can no longer be in a constant set or be a constant map key.
