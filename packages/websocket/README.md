# Angel3 Websocket

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_websocket?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/websocket/LICENSE)

WebSocket plugin for Angel3 framework. This plugin broadcasts events from hooked services via WebSockets. In addition, it adds itself to the app's IoC container as `AngelWebSocket`, so that it can be used in controllers as well.

WebSocket contexts are add to `req.properties` as `'socket'`.

## Usage

### Server-side

```dart
import "package:angel3_framework/angel3_framework.dart";
import "package:angel3_websocket/server.dart";

void main() async {
  var app =  Angel();

  var ws =  AngelWebSocket();
  
  // This is a plug-in. It hooks all your services,
  // to automatically broadcast events.
  await app.configure(ws.configureServer);
  
  // Listen for requests at `/ws`.
  app.all('/ws', ws.handleRequest);
}

```

Filtering events is easy with hooked services. Just return a `bool`, whether synchronously or asynchronously.

```dart
myService.properties['ws:filter'] = (HookedServiceEvent e, WebSocketContext socket) async {
  return true;
}

myService.index({
  'ws:filter': (e, socket) => ...;
});
```

#### Adding Handlers within a Controller

`WebSocketController` extends a normal `Controller`, but also listens to WebSockets.

```dart
import 'dart:async';
import "package:angel3_framework/angel3_framework.dart";
import "package:angel3_websocket/server.dart";

@Expose("/")
class MyController extends WebSocketController {
  // A reference to the WebSocket plug-in is required.
  MyController(AngelWebSocket ws):super(ws);
  
  @override
  void onConnect(WebSocketContext socket) {
    // On connect...
  }
  
  // Dependency injection works, too..
  @ExposeWs("read_message")
  void sendMessage(WebSocketContext socket, WebSocketAction action, Db db) async {
    socket.send(
      "found_message",
      db.collection("messages").findOne(where.id(action.data['message_id'])));
  }

  // Event filtering
  @ExposeWs("foo")
  void foo() {
    broadcast( WebSocketEvent(...), filter: (socket) async => ...);
  }
}
```

### Client Use

This repo also provides two client libraries `browser` and `io` that extend the base `angel3_client` interface, and allow you to use a very similar API on the client to that of the server.

The provided clients also automatically try to reconnect their WebSockets when disconnected, which means you can restart your development server without having to reload browser windows.

They also provide streams of data that pump out filtered data as it comes in from the server.

Clients can even perform authentication over WebSockets.

#### In the Browser

```dart
import "package:angel3_websocket/browser.dart";

void main() async {
  Angel app =  WebSockets("/ws");
  await app.connect();

  var Cars = app.service("api/cars");

  Cars.onCreated.listen((car) => print("New car: $car"));

  // Happens asynchronously
  Cars.create({"brand": "Toyota"});

  // Authenticate a WebSocket, if you were not already authenticated...
  app.authenticateViaJwt('<some-jwt>');

  // Listen for arbitrary events
  app.on['custom_event'].listen((event) {
    // For example, this might be sent by a
    // WebSocketController.
    print('Hi!');
  });
}
```

#### CLI Client

```dart
import "package:angel3_framework/common.dart";
import "package:angel3_websocket/io.dart";

// You can include these in a shared file and access on both client and server
class Car extends Model {
  int year;
  String brand, make;

  Car({this.year, this.brand, this.make});

  @override String toString() => "$year $brand $make";
}

void main() async {
  Angel app =  WebSockets("/ws");

  // Wait for WebSocket connection...
  await app.connect();

  var Cars = app.service("api/cars", type: Car);

  Cars.onCreated.listen((Car car) {
      // Automatically deserialized into a car :)
      //
      // I just bought a new 2016 Toyota Camry!
      print("I just bought a new $car!");
  });

  // Happens asynchronously
  Cars.create({"year": 2016, "brand": "Toyota", "make": "Camry"});

  // Authenticate a WebSocket, if you were not already authenticated...
  app.authenticateViaJwt('<some-jwt>');
}
```
