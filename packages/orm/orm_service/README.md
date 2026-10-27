# Angel3 ORM Service

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_service?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/orm_service/LICENSE)

Service implementation that wraps over Angel3 ORM Query classes.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
    angel3_orm_service: ^10.0.0
```

## Usage

Brief snippet (check `example/main.dart` for setup, etc.):

```dart
// Create an ORM-backed service.
var todoService = OrmService<int, Todo, TodoQuery>(
  executor,
  () => TodoQuery(),
  readData: (req, res) => todoSerializer.decode(req.bodyAsMap),
);

// Because we provided `readData`, the todoService can face the Web.
// **IMPORTANT:** Providing the type arguments is an ABSOLUTE MUST if your
// model has `int` IDs (this is the case when using `angel3_orm_generator`
// and `Model`).
app.use<int, Todo, OrmService<int, Todo, TodoQuery>>(
  '/api/todos',
  todoService,
);
```

## Querying

A REST client can filter and sort the records of `index` and the other methods with query parameters:

* `?level=100` matches the records whose `level` column is `100`. The value is converted to the column's type (a number, a boolean or a date). A parameter that names no column, or a value that cannot be converted, is a `400 Bad Request`.
* `?$sort=name` sorts by a column. Only the query's own columns are accepted, as the name is written into the SQL; any other is a `400 Bad Request`. On the server, `$sort` can also be a map of columns to `1` or `-1`, such as `{'name': -1}` for descending order.

On the server, `params['query']` can also be a callback that is given the query, such as `(TodoQuery q) => q.where!.isComplete.isFalse`.

## Updates

`modify` (`PATCH`) changes only the fields it is given, and `update` (`PUT`) replaces every field of the record. Both change one record, by its id.
