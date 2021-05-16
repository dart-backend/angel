import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:angel3_pub_sub/angel3_pub_sub.dart';
import 'package:angel3_pub_sub/json_rpc_2.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  late ServerSocket serverSocket;
  late Server server;
  late Client client1, client2, client3;
  late JsonRpc2Client trustedClient;
  JsonRpc2Adapter adapter;

  setUp(() async {
    serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);

    adapter = JsonRpc2Adapter(
        serverSocket.map<StreamChannel<String>>(streamSocket),
        isTrusted: true);

    var socket1 =
        await Socket.connect(InternetAddress.loopbackIPv4, serverSocket.port);
    var socket2 =
        await Socket.connect(InternetAddress.loopbackIPv4, serverSocket.port);
    var socket3 =
        await Socket.connect(InternetAddress.loopbackIPv4, serverSocket.port);
    var socket4 =
        await Socket.connect(InternetAddress.loopbackIPv4, serverSocket.port);

    client1 = JsonRpc2Client('json_rpc_2_test::secret', streamSocket(socket1));
    client2 = JsonRpc2Client('json_rpc_2_test::secret2', streamSocket(socket2));
    client3 = JsonRpc2Client('json_rpc_2_test::secret3', streamSocket(socket3));
    trustedClient = JsonRpc2Client(null, streamSocket(socket4));

    server = Server([adapter])
      ..registerClient(const ClientInfo('json_rpc_2_test::secret'))
      ..registerClient(const ClientInfo('json_rpc_2_test::secret2'))
      ..registerClient(const ClientInfo('json_rpc_2_test::secret3'))
      ..registerClient(
          const ClientInfo('json_rpc_2_test::no_publish', canPublish: false))
      ..registerClient(const ClientInfo('json_rpc_2_test::no_subscribe',
          canSubscribe: false))
      ..start();

    var sub = await client3.subscribe('foo');
    sub.listen((data) {
      print('Client3 caught foo: $data');
    });
  });

  tearDown(() {
    Future.wait([
      server?.close(),
      client1?.close(),
      client2?.close(),
      client3?.close()
    ]);
  });

  group('trusted', () {
    test('can publish', () async {
      await trustedClient.publish('hey', 'bye');
      expect(trustedClient.clientId, isNotNull);
    });
    test('can sub/unsub', () async {
      String? clientId;
      await trustedClient.publish('heyaaa', 'byeaa');
      expect(clientId = trustedClient.clientId, isNotNull);

      var sub = await trustedClient.subscribe('yeppp');
      expect(trustedClient.clientId, clientId);

      await sub.unsubscribe();
      expect(trustedClient.clientId, clientId);
    });
  });

  test('subscribers receive published events', () async {
    var sub = await client2.subscribe('foo');
    await client1.publish('foo', 'bar');
    expect(await sub.first, 'bar');
  });

  test('subscribers are not sent their own events', () async {
    var sub = await client1.subscribe('foo');
    await client1.publish('foo',
        '<this should never be sent to client1, because client1 sent it.>');
    await sub.unsubscribe();
    expect(await sub.isEmpty, isTrue);
  });

  test('can unsubscribe', () async {
    var sub = await client2.subscribe('foo');
    await client1.publish('foo', 'bar');
    await sub.unsubscribe();
    await client1.publish('foo', '<client2 will not catch this!>');
    expect(await sub.length, 1);
  });

  group('json_rpc_2_server', () {
    test('reject unknown client id', () async {
      try {
        var sock = await Socket.connect(
            InternetAddress.loopbackIPv4, serverSocket.port);
        var client =
            JsonRpc2Client('json_rpc_2_test::invalid', streamSocket(sock));
        await client.publish('foo', 'bar');
        throw 'Invalid client ID\'s should throw an error, but they do not.';
      } on PubSubException catch (e) {
        print('Expected exception was thrown: ${e.message}');
      }
    });

    test('reject unprivileged publish', () async {
      try {
        var sock = await Socket.connect(
            InternetAddress.loopbackIPv4, serverSocket.port);
        var client =
            JsonRpc2Client('json_rpc_2_test::no_publish', streamSocket(sock));
        await client.publish('foo', 'bar');
        throw 'Unprivileged publishes should throw an error, but they do not.';
      } on PubSubException catch (e) {
        print('Expected exception was thrown: ${e.message}');
      }
    });

    test('reject unprivileged subscribe', () async {
      try {
        var sock = await Socket.connect(
            InternetAddress.loopbackIPv4, serverSocket.port);
        var client =
            JsonRpc2Client('json_rpc_2_test::no_subscribe', streamSocket(sock));
        await client.subscribe('foo');
        throw 'Unprivileged subscribes should throw an error, but they do not.';
      } on PubSubException catch (e) {
        print('Expected exception was thrown: ${e.message}');
      }
    });
  });
}

StreamChannel<String> streamSocket(Socket socket) {
  var channel = _SocketStreamChannel(socket);
  return channel
      .cast<List<int>>()
      .transform(StreamChannelTransformer.fromCodec(utf8));
}

class _SocketStreamChannel extends StreamChannelMixin<List<int>> {
  _SocketSink? _sink;
  final Socket socket;

  _SocketStreamChannel(this.socket);

  @override
  StreamSink<List<int>> get sink => _sink ??= _SocketSink(socket);

  @override
  Stream<List<int>> get stream => socket;
}

class _SocketSink extends StreamSink<List<int>> {
  final Socket socket;

  _SocketSink(this.socket);

  @override
  void add(List<int> event) {
    socket.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    Zone.current.errorCallback(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    return socket.addStream(stream);
  }

  @override
  Future close() {
    return socket.close();
  }

  @override
  Future get done => socket.done;
}
