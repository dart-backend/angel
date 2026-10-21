import 'dart:async';
import 'dart:isolate';

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

  test('close does not hang when the server is gone', () async {
    var sync = PubSubSynchronizationChannel(
      pub_sub.IsolateClient('angel_sync1', adapter.receivePort.sendPort),
      closeTimeout: const Duration(milliseconds: 200),
    );
    // Subscribed, then the server goes away without telling the client.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await server.close();
    await sync.close().timeout(const Duration(seconds: 5));
  });

  test('close does not hang when the server never answers', () async {
    var nobody = ReceivePort();
    addTearDown(nobody.close);
    var sync = PubSubSynchronizationChannel(
      pub_sub.IsolateClient('angel_sync1', nobody.sendPort),
      closeTimeout: const Duration(milliseconds: 200),
    );
    await sync.close().timeout(const Duration(seconds: 5));
  });

  test('an event without a name is an error of the stream', () async {
    var sync = channel('angel_sync1');
    addTearDown(sync.close);
    var error = expectLater(
      sync.stream.first.timeout(const Duration(seconds: 5)),
      throwsA(isA<FormatException>()),
    );
    // Let the channel subscribe, then publish what no instance sends.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    var other = pub_sub.IsolateClient(
      'angel_sync2',
      adapter.receivePort.sendPort,
    );
    addTearDown(other.close);
    await other.publish(PubSubSynchronizationChannel.eventName, {'data': 42});
    await error;
  });

  test('closing the sink waits for the channel to close', () async {
    var closed = false;
    var client = _NotifyingClient(
      pub_sub.IsolateClient('angel_sync1', adapter.receivePort.sendPort),
      () => closed = true,
    );
    var sync = PubSubSynchronizationChannel(client);
    await sync.sink.close();
    expect(closed, isTrue);
  });
}

/// Tells when it is closed.
class _NotifyingClient implements pub_sub.Client {
  final pub_sub.Client inner;
  final void Function() onClose;

  _NotifyingClient(this.inner, this.onClose);

  @override
  Future publish(String eventName, value) => inner.publish(eventName, value);

  @override
  Future<pub_sub.ClientSubscription> subscribe(String eventName) =>
      inner.subscribe(eventName);

  @override
  Future close() async {
    await inner.close();
    onClose();
  }
}
