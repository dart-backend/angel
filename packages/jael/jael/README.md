# jael3
[![version](https://img.shields.io/badge/pub-v4.0.0-brightgreen)](https://pub.dartlang.org/packages/jael3)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/jael/jael3/LICENSE)

A simple server-side HTML templating engine for Dart.

[See documentation.](https://docs.angel-dart.dev/packages/front-end/jael)

# Installation
In your `pubspec.yaml`:

```yaml
dependencies:
  jael3: ^4.0.0
```

# API
The core `jael` package exports classes for parsing Jael templates,
an AST library, and a `Renderer` class that generates HTML on-the-fly.

```dart
import 'package:angel3_code_buffer/code_buffer.dart';
import 'package:jael3/jael.dart' as jael;
import 'package:angel3_symbol_table/symbol_table.dart';

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

Pre-processing (i.e. handling of blocks and includes) is handled
by `package:jael3_preprocessor.`.
