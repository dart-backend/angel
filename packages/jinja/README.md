# Jinja View Template for Angel3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_jinja?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/jinja/LICENSE)

A service that renders Jinja2 view template into HTML for [Angel3](https://angel3-framework.web.app) framework. Ported from Python to Dart.

## Example

```dart
import 'dart:io';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';
import 'package:angel_jinja/angel_jinja.dart';
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
