import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

void main() async {
  var app = Angel(reflector: MirrorsReflector());

  app.viewGenerator = (name, [data]) async =>
      'View generator invoked with name $name and data: $data';

  // Index route. Returns JSON.
  app.get('/', (req, res) => res.render('index', {'foo': 'bar'}));

  var http = AngelHttp(app);
  var server = await http.startServer('127.0.0.1', 3000);
  var url = 'http://${server.address.address}:${server.port}';
  print('Listening at $url');
}
