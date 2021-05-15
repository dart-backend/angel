# angel3_framework
[![version](https://img.shields.io/badge/pub-v4.0.2-brightgreen)](https://pub.dartlang.org/packages/angel3_framework)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/framework/LICENSE)

A high-powered HTTP server with support for dependency injection, sophisticated routing and more.

This is the core of the [Angel](https://github.com/dukefirehawk/angel/tree/angel3) framework.
To build real-world applications, please see the [homepage](https://angel-dart.dev).

```dart
import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';

main() async {
    var app = Angel(reflector: MirrorsReflector());

    // Index route. Returns JSON.
    app.get('/', (req, res) => res.write('Welcome to Angel!'));
  
    // Accepts a URL like /greet/foo or /greet/bob.
    app.get(
      '/greet/:name',
      (req, res) {
        var name = req.params['name'];
        res
          ..write('Hello, $name!')
          ..close();
      },
    );
    
    // Pattern matching - only call this handler if the query value of `name` equals 'emoji'.
    app.get(
      '/greet',
      ioc((@Query('name', match: 'emoji') String name) => '😇🔥🔥🔥'),
    );
    
    // Handle any other query value of `name`.
    app.get(
      '/greet',
      ioc((@Query('name') String name) => 'Hello, $name!'),
    );
    
    // Simple fallback to throw a 404 on unknown paths.
    app.fallback((req, res) {
      throw AngelHttpException.notFound(
        message: 'Unknown path: "${req.uri.path}"',
      );
    });

    var http = AngelHttp(app);
    var server = await http.startServer('127.0.0.1', 3000);
    var url = 'http://${server.address.address}:${server.port}';
    print('Listening at $url');
    print('Visit these pages to see Angel in action:');
    print('* $url/greet/bob');
    print('* $url/greet/?name=emoji');
    print('* $url/greet/?name=jack');
    print('* $url/nonexistent_page');
}
```
