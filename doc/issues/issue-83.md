# Issue 83

How can I use "angel3_websocket" package without annotations, I haven't seen an example of usage without using a Controller Class with annotations.
bootstrap.dart

library jubarte_server;
import 'dart:async';
import 'package:angel3_configuration/angel3_configuration.dart';
import 'package:angel3_cors/angel3_cors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_websocket/server.dart';
import 'package:dotenv/dotenv.dart' show load, env;
import 'package:file/local.dart';
import 'package:jubarte2server/app_config.dart';
import 'db_connect.dart';
import 'routes.dart' as routes;

Future configureServer(Angel app) async {
  //--------------------- Configura o WebSocket -----------------------------
  var ws = AngelWebSocket(app);
  ws.onAction.listen((event) {
    print('WebSocket onAction eventName: ${event.eventName} |  ${event.data}');
  });

  await app.configure(ws.configureServer);

  app.all('/ws', ws.handleRequest);
  //--------------------------------------------------

  // The default options will allow CORS for any request.
  // Combined with `fallback`, you can enable CORS application-wide.
  app.fallback(cors());

  ...

My implementation without using Angel is like this and ping works fine
websocket_server.dart

import 'dart:io';

void main() async {
  final server = await HttpServer.bind('localhost', 9223); // 5600);
  server.transform(WebSocketTransformer()).listen(onWebSocketData);
}

void onWebSocketData(WebSocket client) {
  client.listen((data) {
    print('onWebSocketData $data');
    client.add('Echo: $data');
  });
}

websocket_web_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:html';

class WebsocketService {
  WebSocket webSocket;

  WebsocketService() {
    connect();
  }

  void connect() {
    //ws://localhost:3150
    webSocket = WebSocket('ws://localhost:3150/ws');

    ///ws
    webSocket.onOpen.first.then((_) {
      onConnected();
      sendws('Hello websocket server');
      webSocket.onClose.first.then((_) {
        print('Connection disconnected to ${webSocket.url}');
        onDisconnected();
      });
    });
    webSocket.onError.first.then((_) {
      print('Failed to connect to ${webSocket.url}. '
          'Please run bin/server.dart and try again.');
      onDisconnected();
    });
  }

  void onConnected() {
    webSocket.onMessage.listen((e) {
      onMessage(e.data);
    });
  }

  void onDisconnected() {
    print('Disconnected, trying again in 3s');
    Timer(Duration(seconds: 3), () {
      connect();
    });
  }

  void onMessage(data) {
    //var json = jsonDecode(data);
    //var echoFromServer = json['response'];
    print('Received message: $data');

    Timer(Duration(seconds: 3), () {
      //Send a new message to server after 3s
      var now = DateTime.now().toString();
      sendws('Time: $now');
    });
  }

  void sendws(String msg) {
    var request = '{"echo": "$msg"}';
    print('Send message to server: $request');
    webSocket.send(request);
  }
}
