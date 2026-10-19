# Jael 3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/jael3?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/jael/jael/LICENSE)

A simple server-side HTML templating engine for Dart.

[See documentation.](https://angel3-docs.dukefirehawk.com/packages/front-end/jael)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  jael3: ^10.0.0
```

## API

The core `jael3` package exports classes for parsing Jael templates, an AST library, and a `Renderer` class that generates HTML on-the-fly.

```dart
import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';
import 'package:jael3/jael3.dart' as jael;

void myFunction() {
    const template = '''
<html>
  <body>
    <h1>Hello</h1>
    <img src=profile['avatar']>
  </body>
</html>
''';

    var buf = CodeBuffer();
    var document = jael.parseDocument(template, sourceUrl: 'test.jael', asDSX: false);
    var scope = SymbolTable(values: {
      'profile': {
        'avatar': 'thosakwe.png',
      }
    });

    const jael.Renderer().render(document, buf, scope);
    print(buf);
}
```

Pre-processing (i.e. handling of blocks and includes) is handled by `package:jael3_preprocessor.`.

## Members of values

`{{ user.name }}` reads the member `name` of `user`, of the first of these that has it:

1. the `memberResolver` given to `Renderer.render` (`angel3_jael` gives one that reads the members through the app's reflector);
2. a key of a `Map` (a key wins over a member of `Map`: `{{ m.length }}` of `{'length': 1}` is `1`);
3. a common member of a core type: of `String`, `Iterable` and `List`, `Map`, `MapEntry`, `num` and `int`, `DateTime` and `Duration`, such as `length`, `first`, `join`, `toUpperCase`, `toInt`, `toStringAsFixed` or `year`;
4. a key of the value's `toJson()`, as of an `@serializable` model.

`jael3` does not use `dart:mirrors`, so a getter of another class is read only through a `memberResolver`, which returns `noMember` for those it does not know, or `toJson()`:

```dart
const jael.Renderer().render(
  document,
  buf,
  scope,
  memberResolver: (target, name) => switch ((target, name)) {
    (User u, 'name') => u.name,
    (User u, 'isAdmin') => u.isAdmin,
    _ => jael.noMember,
  },
);
```
