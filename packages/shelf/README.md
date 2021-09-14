# Angel3 Shelf

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_shelf?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dukefirehawk/angel/tree/angel3/packages/shelf/LICENSE)

**Replacement of `package:angel_shelf` with breaking changes to support NNBD.**

Shelf interop with Angel3. This package lets you run `package:shelf` handlers via a custom adapter.

Use the code in this repo to embed existing Angel/shelf apps into
other Angel/shelf applications. This way, you can migrate legacy applications without
having to rewrite your business logic.

This will make it easy to layer your API over a production application,
rather than having to port code.

- [Angel3 Shelf](#angel3-shelf)
  - [Usage](#usage)
    - [embedShelf](#embedshelf)
    - [Communicating with Angel with embedShelf](#communicating-with-angel-with-embedshelf)
    - [AngelShelf](#angelshelf)

## Usage

### embedShelf

This is a compliant `shelf` adapter that acts as an Angel request handler. You can use it as a middleware,
or attach it to individual routes.

```dart
import 'dart:io';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_shelf/angel3_shelf.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'api/api.dart';

void main() async {
  var app = Angel();
  var http = AngelHttp(app);

  // Angel routes on top
  await app.mountController<ApiController>();

  // Re-route all other traffic to an
  // existing application.
  app.fallback(embedShelf(
    shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(_echoRequest)
  ));

  // Or, only on a specific route:
  app.get('/shelf', wrappedShelfHandler);

  await http.startServer(InternetAddress.loopbackIPV4, 3000);
  print(http.uri);
}
```

### Communicating with Angel with embedShelf

You can communicate with Angel:

```dart
handleRequest(shelf.Request request) {
  // Access original Angel request...
  var req = request.context['angel_shelf.request'] as RequestContext;

  // ... And then interact with it.
  req.container.registerNamedSingleton<Foo>('from_shelf', Foo());

  // `req.container` is also available.
  var container = request.context['angel_shelf.container'] as Container;
  container.make<Truck>().drive();
}
```

### AngelShelf

Angel 2 brought about the generic `Driver` class, which is implemented by `AngelHttp`, `AngelHttp2`, `AngelGopher`, etc., and provides the core infrastructure for request handling in Angel.

`AngelShelf` is an implementation that wraps shelf requests and responses in their Angel equivalents. Using it is as simple using as using `AngelHttp`, or any other driver:

```dart
// Create an AngelShelf driver.
// If we have startup hooks we want to run, we need to call
// `startServer`. Otherwise, it can be omitted.
// Of course, if you call `startServer`, know that to run
// shutdown/cleanup logic, you need to call `close` eventually,
// too.
var angelShelf = AngelShelf(app);
await angelShelf.startServer();

await shelf_io.serve(angelShelf.handler, InternetAddress.loopbackIPv4, 8081);
```

You can also use the `AngelShelf` driver as a shelf middleware - just use
`angelShelf.middleware` instead of `angelShelf.handler`. When used as a middleware,
if the Angel response context is still open after all handlers run (i.e. no routes were
matched), the next shelf handler will be called.

```dart
var handler = shelf.Pipeline()
  .addMiddleware(angelShelf.middleware)
  .addHandler(createStaticHandler(...));
```
