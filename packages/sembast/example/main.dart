import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_sembast/angel3_sembast.dart';
import 'package:logging/logging.dart';
import 'package:sembast/sembast_io.dart';

void main() async {
  var app = Angel();
  var db = await databaseFactoryIo.openDatabase('todos.db');

  app
    ..logger = (Logger('angel_sembast_example')..onRecord.listen(print))
    ..use('/api/todos', SembastService(db, store: 'todos'))
    ..shutdownHooks.add((_) => db.close());

  var http = AngelHttp(app);
  var server = await http.startServer('127.0.0.1', 3000);
  var uri = Uri(
    scheme: 'http',
    host: server.address.address,
    port: server.port,
  );
  print('angel_sembast example listening at $uri');
}
