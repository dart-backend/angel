# Jinja View Template for Angel3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_jinja?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/jinja/LICENSE)

A service that renders Jinja2 view template into HTML for [Angel3](https://angel3-framework.web.app) framework. Ported from Python to Dart.

## Example

```dart
import 'dart:io';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_jinja/angel3_jinja.dart';
import 'package:path/path.dart' as p;

void main() async {
  var app = Angel();
  var http = AngelHttp(app);
  var viewsDir = p.join(
    p.dirname(
      p.fromUri(Platform.script),
    ),
    'views',
  );

  // Enable Jinja2 views
  await app.configure(jinja(path: viewsDir));

  // Add routes.
  // See: https://github.com/ykmnkmi/jinja.dart/blob/master/example/bin/server.dart

  app
    ..get('/', (req, res) => res.render('index.html'))
    ..get('/hello', (req, res) => res.render('hello.html', {'name': 'user'}))
    ..get('/hello/:name', (req, res) => res.render('hello.html', req.params));

  app.fallback((req, res) {
    res
      ..statusCode = 404
      ..write('404 Not Found :(');
  });

  // Start the server
  await http.startServer('127.0.0.1', 3000);
  print('Listening at ${http.uri}');
}
```

## Escaping

Values are not HTML-escaped. Escape every value that is not trusted HTML, such as one from the request, with the `e` (or `escape`) filter:

```html
<p>hello {{ name | e }}!</p>
```

## Views

A view name that resolves outside the views directory (`../secret.html`, an absolute path, a symbolic link out of it), that has none of the extensions in `ext`, or that does not exist, is a 404. In production, templates are kept parsed; otherwise they are read again on every render.
