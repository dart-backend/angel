# angel3_html_builder
[![version](https://img.shields.io/badge/pub-v2.0.1-brightgreen)](https://pub.dartlang.org/packages/angel3_html_builder)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/html_builder/LICENSE)

Build HTML AST's and render them to HTML.

This can be used as an internal DSL, i.e. for a templating engine.

# Installation
In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_html_builder: ^2.0.0
```

# Usage
```dart
import 'package:angel3_html_builder/angel3_html_builder.dart';

void main() {
    // Akin to React.createElement(...);
    var $el = h('my-element', p: {}, c: []);


    // Attributes can be plain Strings.
    h('foo', p: {
        'bar': 'baz'
    });

i    // Null attributes do not appear.
    h('foo', p: {
        'does-not-appear': null
    });

    // If an attribute is a bool, then it will only appear if its value is true.
    h('foo', p: {
        'appears': true,
        'does-not-appear': false
    });
:
    // Or, a String or Map.
    h('foo', p: {
        'style': 'background-color: white; color: red;'
    });

    h('foo', p: {
        'style': {
            'background-color': 'white',
            'color': 'red'
/        }
    });

    // Or, a String or Iterable.
    h('foo', p: {
        'class': 'a b'
    });

    h('foo', p: {
        'class': ['a', 'b']
    });
}
```

Standard HTML5 elements:
```dart
import 'package:angel3_html_builder/elements.dart';

void main() {
    var $dom = html(lang: 'en', c: [
        head(c: [
            title(c: [text('Hello, world!')])
        ]),
        body(c: [
            h1(c: [text('Hello, world!')]),
            p(c: [text('Ok')])
        ])
    ]);
}
```

Rendering to HTML:
```dart
String html = StringRenderer().render($dom);
```

Example with the [Angel](https://github.com/dukefirehawk/angel/tree/angel3) server-side framework,
which has [dedicated html_builder support](https://github.com/dukefirehawk/angel/tree/html):

```dart
import 'dart:io';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_html_builder/elements.dart';

configureViews(Angel app) async {
    app.get('/foo/:id', (req, res) async {
        var foo = await app.service('foo').read(req.params['id']);
        return html(c: [
            head(c: [
                title(c: [text(foo.name)])
            ]),
            body(c: [
                h1(c: [text(foo.name)])
            ])
        ]);
    });
}
```
