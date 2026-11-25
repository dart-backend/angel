/// The same three routes on plain `dart:io`, as the ceiling of what a
/// framework on `dart:io` can reach.
library;

import 'dart:io';
import 'dart:isolate';

import 'env.dart';

Future<void> main() async {
  for (var i = 0; i < isolateCount - 1; i++) {
    await Isolate.spawn((_) => startServer(), null);
  }

  await startServer();
  print('raw listening on $port with $isolateCount isolates');
}

Future<void> startServer() async {
  var server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    port,
    shared: true,
  );
  server.listen((request) {
    var response = request.response;
    var path = request.uri.path;
    if (request.method == 'GET' && path.startsWith('/user/')) {
      response.write(path.substring(6));
    } else if (!(path == '/' && request.method == 'GET') &&
        !(path == '/user' && request.method == 'POST')) {
      response.statusCode = 404;
    }
    response.close();
  });
}
