import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

void main() async {
  var x = 0;
  var c = Completer();
  var exit = ReceivePort();
  var isolates = <Isolate>[];

  exit.listen((_) {
    if (++x >= 50) {
      c.complete();
    }
  });

  for (var i = 1; i < Platform.numberOfProcessors; i++) {
    var isolate = await Isolate.spawn(serverMain, null);
    isolates.add(isolate);
    print('Spawned isolate #${i + 1}...');

    isolate.addOnExitListener(exit.sendPort);
  }

  serverMain(null);

  print('Angel listening at http://localhost:3000');
  await c.future;
}

void serverMain(_) async {
  var app = Angel();
  var http =
      AngelHttp.custom(app, startShared, useZone: false); // Run a cluster

  app.get('/', (req, res) {
    return res.serialize({
      'foo': 'bar',
      'one': [2, 'three'],
      'bar': {'baz': 'quux'}
    });
  });

  app.errorHandler = (e, req, res) {
    print(e.message);
    print(e.stackTrace);
  };

  var server = await http.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
