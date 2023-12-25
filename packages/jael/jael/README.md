# Jael 3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/jael3?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/jael/jael/LICENSE)

A simple server-side HTML templating engine for Dart.

[See documentation.](https://angel3-docs.dukefirehawk.com/packages/front-end/jael)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  jael3: ^8.0.0
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
