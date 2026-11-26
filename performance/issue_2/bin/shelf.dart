/// The Shelf app of issue 2.
library;

import 'dart:isolate';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'env.dart';

Future<void> main() async {
  for (var i = 0; i < isolateCount - 1; i++) {
    await Isolate.spawn((_) => startServer(), null);
  }

  // The last server runs in the main isolate, to keep it running.
  await startServer();
  print('shelf listening on $port with $isolateCount isolates');
}

Future<void> startServer() async {
  var app = Router();

  app.get('/', (Request request) => Response.ok(''));

  app.post('/user', (Request request) => Response.ok(''));

  app.get('/user/<user>', (Request request, String user) => Response.ok(user));

  await shelf_io.serve(app.call, '0.0.0.0', port, shared: true);
}
