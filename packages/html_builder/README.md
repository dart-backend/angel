# html_builder
[![Pub](https://img.shields.io/pub/v/html_builder.svg)](https://pub.dartlang.org/packages/html_builder)
[![build status](https://travis-ci.org/thosakwe/html_builder.svg)](https://travis-ci.org/thosakwe/html_builder)

Build HTML AST's and render them to HTML.

This can be used as an internal DSL, i.e. for a templating engine.

# Installation
In your `pubspec.yaml`:

```yaml
dependencies:
  html_builder: ^1.0.0
```

# Usage
```dart
import 'package:html_builder/html_builder.dart';

main() {
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
import 'package:html_builder/elements.dart';

main() {
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
String html = new StringRenderer().render($dom);
```

Example with the [Angel](https://github.com/angel-dart/angel) server-side framework,
which has [dedicated html_builder support](https://github.com/angel-dart/html):

```dart
import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:html_builder/elements.dart';

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
