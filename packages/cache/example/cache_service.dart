import 'package:angel3_cache/angel3_cache.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

void main() async {
  var app = Angel();

  app.use(
    '/api/todos',
    CacheService(
        cache: MapService(),
        database: AnonymousService(index: ([params]) {
          print(
              'Fetched directly from the underlying service at ${DateTime.now()}!');
          return ['foo', 'bar', 'baz'];
        }, read: (dynamic id, [params]) {
          return {id: '$id at ${DateTime.now()}'};
        })),
  );

  var http = AngelHttp(app);
  var server = await http.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
