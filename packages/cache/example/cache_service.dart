import 'package:angel_cache/angel_cache.dart';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';

main() async {
  var app = Angel();

  app.use(
    '/api/todos',
    CacheService(
      cache: MapService(),
      database: AnonymousService(index: ([params]) {
        print(
            'Fetched directly from the underlying service at ${new DateTime.now()}!');
        return ['foo', 'bar', 'baz'];
      }, read: (id, [params]) {
        return {id: '$id at ${new DateTime.now()}'};
      }),
    ),
  );

  var http = AngelHttp(app);
  var server = await http.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
