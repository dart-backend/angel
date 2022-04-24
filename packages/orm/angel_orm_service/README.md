# Angel3 ORM Service

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_servie?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/orm/angel_orm_service/LICENSE)

Service implementation that wraps over Angel3 ORM Query classes.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
    angel3_orm_service: ^6.0.0
```

## Usage

Brief snippet (check `example/main.dart` for setup, etc.):

```dart
// Create an ORM-backed service.
  var todoService = OrmService<int, Todo, TodoQuery>(
      executor, () => TodoQuery(),
      readData: (req, res) => todoSerializer.decode(req.bodyAsMap));

  // Because we provided `readData`, the todoService can face the Web.
  // **IMPORTANT: Providing the type arguments is an ABSOLUTE MUST, if your
  // model has `int` ID's (this is the case when using `angel_orm_generator` and `Model`).
  // **
  app.use<int, Todo, OrmService<int, Todo, TodoQuery>>(
      '/api/todos', todoService);
```
