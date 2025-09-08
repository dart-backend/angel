import 'dart:io';
import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_shelf/angel3_shelf.dart';
import 'package:logging/logging.dart';
import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

void main() async {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(prettyLog);

  // Create a basic Angel server, with some routes.
  var app = Angel(
    logger: Logger('angel3_shelf_demo'),
    reflector: MirrorsReflector(),
  );

  app.get('/angel', (req, res) {
    res.write('Angel embedded within shelf!');
    return false;
  });

  app.get(
    '/hello',
    ioc((@Query('name') String name) {
      return {'hello': name};
    }),
  );

  // Next, create an AngelShelf driver.
  //
  // If we have startup hooks we want to run, we need to call
  // `startServer`. Otherwise, it can be omitted.
  // Of course, if you call `startServer`, know that to run
  // shutdown/cleanup logic, you need to call `close` eventually,
  // too.
  var angelShelf = AngelShelf(app);
  await angelShelf.startServer();

  // Create, and mount, a shelf pipeline...
  // You can also embed Angel as a middleware...
  var mwHandler = shelf.Pipeline()
      .addMiddleware(angelShelf.middleware)
      .addHandler(
        createStaticHandler(
          '.',
          defaultDocument: 'index.html',
          listDirectories: true,
        ),
      );

  // Run the servers.
  await shelf_io.serve(mwHandler, InternetAddress.loopbackIPv4, 8080);
  await shelf_io.serve(angelShelf.handler, InternetAddress.loopbackIPv4, 8081);
  print('Angel as middleware: http://localhost:8080');
  print('Angel as only handler: http://localhost:8081');
}
