import 'package:angel3_cache/angel3_cache.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

void main() async {
  var app = Angel();

  // Cache a glob
  var cache = ResponseCache()
    ..patterns.addAll([
      RegExp('^/?\\w+\\.txt'),
    ]);

  // Handle `if-modified-since` header, and also send cached content
  app.fallback(cache.handleRequest);

  // A simple handler that returns a different result every time.
  app.get(
      '/date.txt', (req, res) => res.write(DateTime.now().toIso8601String()));

  // Support purging the cache.
  app.addRoute('PURGE', '*', (req, res) {
    if (req.ip != '127.0.0.1') {
      throw AngelHttpException.forbidden();
    }

    cache.purge(req.uri!.path);
    print('Purged ${req.uri!.path}');
  });

  // The response finalizer that actually saves the content
  app.responseFinalizers.add(cache.responseFinalizer);

  var http = AngelHttp(app);
  var server = await http.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
