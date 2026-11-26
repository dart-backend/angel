# Issue 2

Why Angel3 is much slower than Shelf and Relic?

## Angel3

```yaml
name: angel3_app

environment:
  sdk: "^3.13.0"

dependencies:
  angel3_framework: ^10.0.1
  logging: any
```

```dart
import 'dart:io';
import 'dart:isolate';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:logging/logging.dart';

Future<void> runServer([Object? _]) async {
  // A detached logger has no listeners, so nothing is printed.
  final app = Angel(
    environment: const AngelEnvironment('production'),
    logger: Logger.detached('angel'),
  );

  app.get('/', (req, res) {});

  app.get('/user/:id', (req, res) {
    res.write(req.params['id']);
  });

  app.post('/user', (req, res) {});

  // `startShared` binds with `shared: true`, one server per isolate.
  await AngelHttp.custom(
    app,
    startShared,
    useZone: false,
  ).startServer(InternetAddress.anyIPv4, 3000);
}

Future<void> main() async {
  for (int i = Platform.numberOfProcessors - 1; i > 0; i--) {
    await Isolate.spawn(runServer, null);
  }

  await runServer();
}
```

## Shelf

```yaml
name: shelf_app

environment:
  sdk: "^3.13.0"

dependencies:
  shelf: ">=1.4.1 <1.5.0"
  shelf_router: any
```

```dart
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'cluster.dart';

void main() {
  scale(startServer);
}

void startServer() async {
  var app = Router();

  app.get('/', (Request request) => Response.ok(''));

  app.post('/user', (Request request) => Response.ok(''));

  app.get('/user/<user>', (Request request, String user) => Response.ok(user));

  await shelf_io.serve(app, '0.0.0.0', 3000, shared: true);
}
```

```dart
import 'dart:io';
import 'dart:isolate';

void scale(void Function() task) async {
  for (var i = 0; i < Platform.numberOfProcessors - 1; i++) {
    Isolate.spawn((_) => task(), null);
  }

  // last server running in main isolate
  // to keep the main isolate running
  task();
}
```

## Relic

```yaml
name: relic_app

environment:
  sdk: "^3.13.0"

dependencies:
  relic: ^2.0.0
  relic_native: ^2.0.0
```

```dart
import 'dart:io';

import 'package:relic/relic.dart';
import 'package:relic_native/relic_native.dart';

Future<void> main() async {
  final app = RelicApp()
    ..get('/', (_) => Response.ok())
    ..post('/user', (_) => Response.ok())
    ..get('/user/:user', (Request request) {
      final user = request.rawPathParameters[#user]!;
      return Response.ok(body: Body.fromString(user));
    });

  await app.serveNative(
    address: InternetAddress.anyIPv4,
    port: 3000,
    noOfIsolates: Platform.numberOfProcessors,
  );
}
```
