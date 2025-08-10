import 'dart:io';
import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart' as srv;
import 'package:angel3_framework/http.dart' as srv;
import 'package:angel3_websocket/io.dart' as ws;
import 'package:angel3_websocket/server.dart' as srv;
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'common.dart';

void main() {
  srv.Angel app;
  late srv.AngelHttp http;
  late ws.WebSockets client;
  srv.AngelWebSocket websockets;
  HttpServer? server;
  late String url;

  setUp(() async {
    app = srv.Angel(reflector: const MirrorsReflector());
    http = srv.AngelHttp(app, useZone: false);

    websockets = srv.AngelWebSocket(app)
      ..onData.listen((data) {
        print('Received by server: $data');
      });

    await app.configure(websockets.configureServer);
    app.all('/ws', websockets.handleRequest);
    await app.configure(GameController(websockets).configureServer);
    app.logger = Logger('angel_auth')..onRecord.listen(print);

    server = await http.startServer();
    url = 'ws://${server!.address.address}:${server?.port}/ws';

    client = ws.WebSockets(url);
    await client.connect(timeout: Duration(seconds: 3));

    print('Connected');

    client
      ..onData.listen((data) {
        print('Received by client: $data');
      })
      ..onError.listen((error) {
        // Auto-fail tests on errors ;)
        stderr.writeln(error);
        error.errors.forEach(stderr.writeln);
        throw error;
      });
  });

  tearDown(() async {
    await client.close();
    await http.close();
    //app = null;
    //server = null;
    //url = null;
  });

  group('controller.io', () {
    test('search', () async {
      client.sendAction(ws.WebSocketAction(eventName: 'search'));
      var search = await client.on['searched'].first;
      print('Searched: ${search.data}');
      expect(Game.fromJson(search.data as Map), equals(johnVsBob));
    });
  });
}
