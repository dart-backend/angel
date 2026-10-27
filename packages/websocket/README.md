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
  var app = Angel();

  var ws = AngelWebSocket(app);
  
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

`@ExposeWs` methods are found through the app's reflector, so the app needs one that can reflect upon the controller. Generate its reflection data with [`angel3_container_generator`](https://pub.dev/packages/angel3_container_generator), which works in a program compiled with `dart compile exe`: mark the controller `@injectable`, add a `part` directive, run `dart run build_runner build`, and give the app a `StaticReflector` of the generated data:

```dart
import 'package:angel3_container/angel3_container.dart';

part 'my_controller.g.dart';

@injectable
@Expose("/")
class MyController extends WebSocketController { ... }

var app = Angel(reflector: StaticReflector.combine([myControllerReflection]));
```

`MirrorsReflector` of `angel3_container_mirrors` finds them too, without generated code, but needs `dart:mirrors`, which `dart compile exe` does not support.

Without a reflector (the default is `ThrowingReflector`), register the handlers with `exposeWs` in `configureWs` instead. A handler is given the action and the socket; other dependencies are made from `socket.request.container`:

```dart
@Expose("/")
class MyController extends WebSocketController {
  MyController(super.ws);

  @override
  void configureWs() {
    exposeWs("read_message", (action, socket) async {
      var db = socket.request.container!.make<Db>();
      socket.send(
        "found_message",
        await db.collection("messages").findOne(where.id(action.data['message_id'])));
    });
  }
}
```

A handler of `exposeWs` is used in place of an `@ExposeWs` method of the same event name.

The `@ExposeWs` methods and the hooks of a `WebSocketController` (`onConnect`, `configureWs`, ...) are not HTTP routes; its other public methods are, as those of a `Controller`, unless annotated `@noExpose`. An `@ExposeWs` method a controller inherits is found if the reflector describes the base class too: mark it `@injectable` as well.

The streams of the server, of a socket and of the clients are broadcast streams: an event is given to those listening when it comes, and is not kept for later. Listen before the event can come, as to `client.on['searched']` before sending the action. On the server, listen to a socket's `onAction` or `onData` in the `onConnection` listener before awaiting anything, as `WebSocketController` does: it listens to them before `onConnect` runs, and handles what comes meanwhile once it has run.

WebSockets are served over HTTP/1.1; a request over HTTP/2 is refused with a `501 Not Implemented`.

### Client Use

This repo also provides two client libraries `browser` and `io` that extend the base `angel3_client` interface, and allow you to use a very similar API on the client to that of the server.

The provided clients also automatically try to reconnect their WebSockets when disconnected, which means you can restart your development server without having to reload browser windows.

They also provide streams of data that pump out filtered data as it comes in from the server.

Clients can even perform authentication over WebSockets.

#### In the Browser

```dart
import "package:angel3_websocket/browser.dart";

void main() async {
  var app = WebSockets("/ws");
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
import "package:angel3_websocket/io.dart";

// You can include these in a shared file and access on both client and server
class Car {
  final int? year;
  final String? brand, make;

  Car({this.year, this.brand, this.make});

  factory Car.fromMap(Map map) => Car(
      year: map["year"] as int?,
      brand: map["brand"] as String?,
      make: map["make"] as String?);

  Map<String, dynamic> toJson() => {"year": year, "brand": brand, "make": make};

  @override String toString() => "$year $brand $make";
}

void main() async {
  var app = WebSockets("ws://localhost:3000/ws");

  // Wait for WebSocket connection...
  await app.connect();

  // The data of a WebSocket service comes as events, and its methods return
  // `null`, so its type is nullable.
  var Cars = app.service<String, Car?>(
    "api/cars",
    deserializer: (x) => Car.fromMap(x as Map),
  );

  Cars.onCreated.listen((car) {
      // Deserialized into a car :)
      //
      // I just bought a new 2016 Toyota Camry!
      print("I just bought a new $car!");
  });

  // Happens asynchronously
  Cars.create(Car(year: 2016, brand: "Toyota", make: "Camry"));

  // Authenticate a WebSocket, if you were not already authenticated...
  app.authenticateViaJwt('<some-jwt>');
}
```
