import 'dart:io';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_shelf/angel3_shelf.dart';
import 'package:logging/logging.dart';
import 'package:angel3_pretty_logging/angel3_pretty_logging.dart';
import 'package:shelf_static/shelf_static.dart';

void main() async {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(prettyLog);

  var app = Angel(logger: Logger('angel3_shelf_demo'));
  var http = AngelHttp(app);

  // `shelf` request handler
  var shelfHandler = createStaticHandler('.',
      defaultDocument: 'index.html', listDirectories: true);

  // Use `embedShelf` to adapt a `shelf` handler for use within Angel.
  var wrappedHandler = embedShelf(shelfHandler);

  // A normal Angel route.
  app.get('/angel', (req, ResponseContext res) {
    res.write('Hooray for `package:angel3_shelf`!');
    return false; // End execution of handlers, so we don't proxy to dartlang.org when we don't need to.
  });

  // Pass any other request through to the static file handler
  app.fallback(wrappedHandler);

  await http.startServer(InternetAddress.loopbackIPv4, 8080);
  print('Running at ${http.uri}');
}
