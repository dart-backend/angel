import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_sync/angel3_sync.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:angel3_websocket/io.dart' as client;
import 'package:angel3_websocket/server.dart';
import 'package:belatuk_pub_sub/isolate.dart' as pub_sub;
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart' as pub_sub;
import 'package:test/test.dart';

void main() {
  late pub_sub.IsolateAdapter adapter;
  late pub_sub.Server server;

  setUp(() {
    adapter = pub_sub.IsolateAdapter();
    server = pub_sub.Server([adapter])
      ..registerClient(const pub_sub.ClientInfo('angel_sync1'))
      ..registerClient(const pub_sub.ClientInfo('angel_sync2'))
      ..start();
  });

  tearDown(() => server.close());

  PubSubSynchronizationChannel channel(String id) =>
      PubSubSynchronizationChannel(
        pub_sub.IsolateClient(id, adapter.receivePort.sendPort),
      );

  test('events propagate', () async {
    // The point of this test is that neither app1 nor app2
    // is aware that the other even exists.
    //
    // Regardless, a WebSocket event broadcast in app1 will be
    // broadcast by app2 as well.
    var app1 = Angel(), app2 = Angel();
    var ws1 = AngelWebSocket(
      app1,
      synchronizationChannel: channel('angel_sync1'),
    );
    var ws2 = AngelWebSocket(
      app2,
      synchronizationChannel: channel('angel_sync2'),
    );

    app1.post('/message', (req, res) async {
      // Manually broadcast. Even though app1 has no clients, it *should*
      // propagate to app2.
      await req.parseBody();
      var message = req.bodyAsMap['message'];
      await ws1.batchEvent(WebSocketEvent(eventName: 'message', data: message));
      return 'Sent: $message';
    });
    await app1.configure(ws1.configureServer);
    var app1Client = await connectTo(app1);

    await app2.configure(ws2.configureServer);
    app2.get('/ws', ws2.handleRequest);
    var http = AngelHttp(app2);
    await http.startServer();
    var app2Client = client.WebSockets(
      http.uri.replace(scheme: 'ws', path: '/ws').toString(),
    );
    await app2Client.connect();

    addTearDown(() async {
      await app2Client.close();
      await app1Client.close();
      // Closing the apps closes the channels' sinks, and so the channels.
      await http.close();
      await app1.close();
    });

    var message = app2Client.on['message'].first;
    var response = await app1Client.post(
      Uri.parse('/message'),
      body: {'message': 'Hello, world!'},
    );
    expect(response.body, '"Sent: Hello, world!"');
    expect(
      (await message.timeout(const Duration(seconds: 5))).data,
      'Hello, world!',
    );
  });

  test('closing the sink closes the channel', () async {
    var sync = channel('angel_sync1');
    var done = sync.stream.toList();
    await sync.sink.close();
    expect(await done.timeout(const Duration(seconds: 5)), isEmpty);
    // Closing again returns the same future.
    expect(identical(sync.close(), sync.close()), isTrue);
  });

  test('closing at once does not fail', () async {
    var sync = channel('angel_sync1');
    await sync.close().timeout(const Duration(seconds: 5));
  });

  test('errors of the client are added to the stream', () async {
    var sync = channel('not registered');
    addTearDown(sync.close);
    expect(
      sync.stream.first.timeout(const Duration(seconds: 5)),
      throwsA(isNot(isA<TimeoutException>())),
    );
  });
}
