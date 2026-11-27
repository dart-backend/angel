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
  angel3_serialize_generator: ^10.1.0
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

### Required fields

A field annotated `@SerializableField(isNullable: false)` is required: `fromMap` throws a `FormatException` of a map without it, and `toMap` of a model whose value of it is `null`.

### Nested models

A field of another `@serializable` class is serialized with that class's serializer, `toMap` and `fromMap`:

* **Nullable**, as `AuthorEntity? author`: `null` is written, and read, as `null`.
* **Non-nullable**, as `AuthorEntity author`, without a default: it is required, and `fromMap` throws of a map without it.

### Constructors

The generated constructor takes each field as a named parameter, and `fromMap` reads each of the map. A model class may also have an unnamed constructor of its own, which the generated one calls:

```dart
@serializable
abstract class AccountEntity {
  AccountEntity(this.region, {required this.owner, int tier = 1})
    : level = tier * 10;

  final String region; // not a field: it has no setter
  final int level;
  String owner;        // a field
  String? get email;   // a field
}
```

* **A parameter of a field**, as `owner`, is given by the field's named parameter: `Account('eu', owner: 'ana')`, and `copyWith` keeps it if it is not given.
* **Any other parameter**, as `region` and `tier`, is a parameter of the generated constructor, of `copyWith` and of `fromMap` too, as the map does not hold it: `AccountSerializer.fromMap(map, 'eu', tier: 2)`. It is named, with its `required` or its default, if it is named, and positional and required if it is positional, even if it is optional. Such a model has no codec, as its `fromMap` takes more than the map.

### JSON Schema

Each serializer also describes the map that its `toMap` writes, as a [JSON Schema](https://json-schema.org/draft/2020-12) (2020-12, as OpenAPI 3.1 has it):

* **`TodoSerializer.jsonSchema`:** the schema, a constant map. A nested model is a `$ref` to `#/components/schemas/` and its name, as an OpenAPI document holds schemas; a nullable field may be `null`; a required one, of `isNullable: false` or a non-nullable field without a default, is in `required`; an enum is the integer of its index, and a `Uint8List` base64 text.
* **`TodoSerializer.schemaName`:** its name, `Todo`.
* **`TodoSerializer.addJsonSchemas(schemas)`:** adds the schema to a map, by name, and those of the models it holds, as `angel3_openapi`'s `OpenApi.schemasOf` does.

A field of a custom `serializer` without `serializesTo` may be anything, as its schema cannot be known.


The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **Regenerate** your models with `dart run build_runner build --delete-conflicting-outputs`: generated `hashCode` getters use `Object.hashAll` instead of `hashObjects`.
* **Class names**: a generated class is named by removing a prefix (`_`, `Entity`), then a suffix (`Entity`), matched by case, so `UserIdentity` keeps its name, where it became `UserId`.
* **`includeAnnotations`**: a value that is not a constant instance of a class or enum fails the build.
* **Code that uses the generator's API**: `SerializableFieldMirror.serializer` and `deserializer` are the names of functions, as `String`s, where they were `Symbol`s.
