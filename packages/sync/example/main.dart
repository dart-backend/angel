import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_sync/angel3_sync.dart';
import 'package:angel3_websocket/server.dart';
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart' as pub_sub;
import 'package:belatuk_pub_sub/isolate.dart' as pub_sub;

/// Runs two instances of an app, on ports 3000 and 3001, whose WebSockets
/// are kept in sync through `package:belatuk_pub_sub`.
///
/// Connect a WebSocket client to ws://localhost:3001/ws, then send a message
/// through the other instance:
///
///     curl -d message=Hello http://localhost:3000/message
///
/// The client receives a `message` event, though it is connected to the
/// instance that did not send it. In production, each instance would run in
/// its own isolate or process, with a `pub_sub` client of its own.
void main() async {
  // The pub/sub server, here over isolate ports. Each instance needs a
  // registered client id.
  var adapter = pub_sub.IsolateAdapter();
  pub_sub.Server([adapter])
    ..registerClient(const pub_sub.ClientInfo('instance-3000'))
    ..registerClient(const pub_sub.ClientInfo('instance-3001'))
    ..start();

  for (var port in [3000, 3001]) {
    var app = Angel();
    var ws = AngelWebSocket(
      app,
      synchronizationChannel: PubSubSynchronizationChannel(
        pub_sub.IsolateClient('instance-$port', adapter.receivePort.sendPort),
      ),
    );
    await app.configure(ws.configureServer);
    app.get('/ws', ws.handleRequest);

    // Broadcasts a message to the WebSockets of every instance.
    app.post('/message', (req, res) async {
      await req.parseBody();
      var message = req.bodyAsMap['message'];
      await ws.batchEvent(WebSocketEvent(eventName: 'message', data: message));
      return 'Sent: $message';
    });

    var http = AngelHttp(app);
    await http.startServer('localhost', port);
    print('Instance listening at ${http.uri}');
  }

  print('Press Ctrl+C to stop.');
}
