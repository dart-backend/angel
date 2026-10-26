import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_websocket/hooks.dart';
import 'package:angel3_websocket/io.dart' as c;
import 'package:angel3_websocket/server.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'controller/common.dart';

/// A server of WebSockets at `/ws`, for a test.
class Server {
  final Angel app;
  final AngelWebSocket sockets;
  final AngelHttp http;
  late final HttpServer server;

  Server(this.app, this.sockets) : http = AngelHttp(app, useZone: false);

  static Future<Server> start({
    Reflector reflector = const ThrowingReflector(),
    List<String> allowedOrigins = const [],
    List<String> allowedProtocols = const [],
    WebSocketResponseSerializer? serializer,
    bool allowAuth = true,
    AngelWebSocket Function(Angel app)? create,
    FutureOr<void> Function(Angel app, AngelWebSocket sockets)? configure,
  }) async {
    var app = Angel(reflector: reflector);
    var sockets =
        create?.call(app) ??
        AngelWebSocket(
          app,
          allowedOrigins: allowedOrigins,
          allowedProtocols: allowedProtocols,
          serializer: serializer,
          allowAuth: allowAuth,
        );
    await app.configure(sockets.configureServer);
    app.all('/ws', sockets.handleRequest);
    await configure?.call(app, sockets);
    var s = Server(app, sockets);
    s.server = await s.http.startServer();
    return s;
  }

  String get ws => 'ws://${server.address.address}:${server.port}/ws';

  Uri http_(String path) =>
      Uri.parse('http://${server.address.address}:${server.port}$path');

  Future<c.WebSockets> client({
    Duration reconnectInterval = const Duration(seconds: 10),
  }) async {
    var client = c.WebSockets(ws, reconnectInterval: reconnectInterval);
    await client.connect(timeout: const Duration(seconds: 5));
    return client;
  }

  Future<void> close() => http.close();
}

/// Counts the connections to [sockets].
class Connections {
  int count = 0;
  final _changes = StreamController<int>.broadcast();

  Connections(AngelWebSocket sockets) {
    sockets.onConnection.listen((_) => _changes.add(++count));
  }

  /// Completes once there have been [n] connections.
  Future<void> reach(int n) => count >= n
      ? Future.value()
      : _changes.stream
            .firstWhere((c) => c >= n)
            .timeout(const Duration(seconds: 5));
}

/// The next event of [name] of [client], or `null` after [timeout].
Future<c.WebSocketEvent?> next(
  c.WebSockets client,
  String name, {
  Duration timeout = const Duration(seconds: 3),
}) => client.on[name].first
    .then<c.WebSocketEvent?>((e) => e)
    .timeout(timeout, onTimeout: () => null);

void main() {
  group('authentication', () {
    late Server server;
    late AngelAuth<Map<String, String>?> auth;
    Map<String, String>? user = {'name': 'foo'};

    setUp(() async {
      auth = AngelAuth(
        jwtKey: 'key',
        serializer: (_) async => 'foo',
        deserializer: (id) async => id == 'foo' ? user : null,
        enforceIp: false,
      );
      server = await Server.start(
        configure: (app, _) => app.configure(auth.configureServer),
      );
    });

    tearDown(() => server.close());

    Future<String?> authenticate(AuthToken token) async {
      var client = await server.client();
      try {
        var error = client.onError.first.then((e) => e.message);
        var authenticated = client.onAuthenticated.first.then((_) => 'ok');
        client.authenticateViaJwt(token.serialize(auth.hmac));
        return await Future.any([error, authenticated]);
      } finally {
        await client.close();
      }
    }

    test('of a valid JWT', () async {
      expect(await authenticate(AuthToken(userId: 'foo')), 'ok');
    });

    test('refuses an expired JWT', () async {
      var expired = AuthToken(
        userId: 'foo',
        lifeSpan: 1000,
        issuedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(await authenticate(expired), 'Expired JWT.');
    });

    test('refuses a JWT of another IP address, if enforceIp', () async {
      var strict = AngelAuth<Map<String, String>?>(
        jwtKey: 'key',
        serializer: (_) async => 'foo',
        deserializer: (id) async => user,
      );
      var other = await Server.start(
        configure: (app, _) => app.configure(strict.configureServer),
      );
      var client = await other.client();
      try {
        var error = client.onError.first.then((e) => e.message);
        client.authenticateViaJwt(
          AuthToken(
            userId: 'foo',
            ipAddress: '203.0.113.9',
          ).serialize(strict.hmac),
        );
        expect(
          await error.timeout(const Duration(seconds: 3)),
          'JWT cannot be accessed from this IP address.',
        );
      } finally {
        await client.close();
        await other.close();
      }
    });

    test('is refused, as such, when allowAuth is false', () async {
      var other = await Server.start(
        allowAuth: false,
        configure: (app, _) => app.configure(auth.configureServer),
      );
      var client = await other.client();
      try {
        var error = client.onError.first.then((e) => e.message);
        client.authenticateViaJwt(
          AuthToken(userId: 'foo').serialize(auth.hmac),
        );
        expect(
          await error.timeout(const Duration(seconds: 3)),
          'Authentication over WebSockets is disabled.',
        );
      } finally {
        await client.close();
        await other.close();
      }
    });

    test('refuses a JWT of a user that does not exist', () async {
      expect(
        await authenticate(AuthToken(userId: 'gone')),
        'The user of the JWT does not exist.',
      );
    });
  });

  group('the origin and protocol', () {
    late Server server;

    setUp(() async {
      server = await Server.start(
        allowedOrigins: ['http://ok.example'],
        allowedProtocols: ['chat'],
      );
    });

    tearDown(() => server.close());

    Future<WebSocket> connect({
      String origin = 'http://ok.example',
      List<String>? protocols,
    }) => WebSocket.connect(
      server.ws,
      headers: {'origin': origin},
      protocols: protocols,
    );

    test('of an allowed origin connects', () async {
      var socket = await connect();
      await socket.close();
    });

    test('of another origin is refused before the upgrade', () async {
      await expectLater(
        connect(origin: 'http://evil.example'),
        throwsA(isA<WebSocketException>()),
      );
      expect(server.sockets.clients, isEmpty);
    });

    test('of protocols none of which is allowed is refused', () async {
      await expectLater(
        connect(protocols: ['other']),
        throwsA(isA<WebSocketException>()),
      );
    });

    test('of protocols is the first that is allowed', () async {
      var socket = await connect(protocols: ['other', 'chat']);
      expect(socket.protocol, 'chat');
      await socket.close();
    });
  });

  group('controllers', () {
    late Server server;
    late c.WebSockets client;

    setUp(() async {
      server = await Server.start(
        reflector: StaticReflector.combine([commonReflection]),
        configure: (app, sockets) async {
          await app.configure(GameController(sockets).configureServer);
          await app.configure(SubGameController(sockets).configureServer);
          await app.configure(PingController(sockets).configureServer);
        },
      );
      client = await server.client();
    });

    tearDown(() async {
      await client.close();
      await server.close();
    });

    test('@ExposeWs methods and hooks are no HTTP routes', () async {
      var http = HttpClient();
      try {
        for (var path in [
          '/game/search',
          '/sub/search',
          '/ping/configure_ws',
        ]) {
          var rs = await (await http.getUrl(server.http_(path))).close();
          await rs.drain<void>();
          expect(rs.statusCode, 404, reason: path);
        }
      } finally {
        http.close();
      }
    });

    test('of more than one, each handles its actions', () async {
      var searched = client.on['searched'].take(2).toList();
      var pong = next(client, 'pong');
      client
        ..sendAction(c.WebSocketAction(eventName: 'search'))
        ..sendAction(c.WebSocketAction(eventName: 'ping'));
      // Of GameController, and of SubGameController, which inherits it.
      expect(
        (await searched.timeout(const Duration(seconds: 3))).map((e) => e.data),
        everyElement(johnVsBob.toJson()),
      );
      expect((await pong)?.data, {'ok': true});
    });
  });

  group('services', () {
    late Server server;
    late c.WebSockets client;
    late HookedService todos;

    setUp(() async {
      server = await Server.start(
        configure: (app, _) {
          todos = app.use('/api/todos', MapService());
          todos.before([
            HookedServiceEvent.created,
          ], doNotBroadcast(Providers.rest));
        },
      );
      client = await server.client();
    });

    tearDown(() async {
      await client.close();
      await server.close();
    });

    test('doNotBroadcast blocks only the providers it is given', () async {
      var created = next(client, 'api/todos::created');
      await client.service('api/todos').create({'text': 'ws'});
      expect((await created)?.data, containsPair('text', 'ws'));

      created = next(client, 'api/todos::created');
      await todos.create({'text': 'rest'}, {'provider': Providers.rest});
      expect(await created, isNull);
    });

    test('the events of all events keep their names', () async {
      var all = client.onAllEvents.first;
      await client.service('api/todos').create({'text': 'a'});
      expect((await all).eventName, 'api/todos::created');
    });

    test('a deserializer is used by the dart:io client', () async {
      var service = client.service<String, Todo?>(
        'api/todos',
        deserializer: (x) => Todo(text: (x as Map)['text'] as String?),
      );
      var created = service.onCreated.first;
      await client.service('api/todos').create({'text': 'typed'});
      expect(await created, isA<Todo>().having((t) => t.text, 'text', 'typed'));
    });

    test('a service of a closed client is closed', () async {
      var other = await server.client();
      var service = other.service('api/todos');
      var done = service.onCreated.toList();
      await other.close();
      expect(await done.timeout(const Duration(seconds: 3)), isEmpty);
    });
  });

  test('a service of a type that is not nullable is refused', () async {
    var server = await Server.start();
    var client = await server.client();
    try {
      expect(
        () => client.service<String, Todo>('api/todos'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => '${e.message}',
            'message',
            contains('service<String, Todo?>'),
          ),
        ),
      );
    } finally {
      await client.close();
      await server.close();
    }
  });

  group('the client', () {
    late Server server;

    setUp(() async => server = await Server.start());
    tearDown(() => server.close());

    test('sends the actions given before it connects', () async {
      var actions = server.sockets.onAction.first;
      var client = c.WebSockets(server.ws);
      client.sendAction(c.WebSocketAction(eventName: 'early'));
      await client.connect();
      expect(
        (await actions.timeout(const Duration(seconds: 3))).eventName,
        'early',
      );
      await client.close();
    });

    const interval = Duration(milliseconds: 20);

    test('does not reconnect once closed', () async {
      var connections = Connections(server.sockets);
      var client = await server.client(reconnectInterval: interval);
      await connections.reach(1);
      await client.close();
      // Of many intervals, in which it would have reconnected.
      await Future.delayed(interval * 10);
      expect(connections.count, 1);
    });

    test('reconnects once when the server closes it', () async {
      var connections = Connections(server.sockets);
      var client = await server.client(reconnectInterval: interval);
      await connections.reach(1);
      await server.sockets.clients.single.close();
      await connections.reach(2);
      // And no more, of the attempts that would overlap.
      await Future.delayed(interval * 10);
      expect(connections.count, 2);
      expect(server.sockets.clients, hasLength(1));
      await client.close();
    });

    test('connect of a connected client is its socket', () async {
      var connections = Connections(server.sockets);
      var client = await server.client();
      var socket = client.socket;
      expect(await client.connect(), same(socket));
      await connections.reach(1);
      expect(server.sockets.clients, hasLength(1));
      await client.close();
    });

    test('a timeout throws a TimeoutException', () async {
      var client = c.WebSockets('ws://10.255.255.1:1/ws');
      await expectLater(
        client.connect(timeout: const Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
      await client.close();
    });
  });

  group('the server', () {
    late Server server;

    tearDown(() => server.close());

    test('fires onClose of a socket the client closes', () async {
      server = await Server.start();
      var closed = server.sockets.onConnection.first.then(
        (socket) => socket.onClose.first,
      );
      var client = await server.client();
      await client.close();
      await closed.timeout(const Duration(seconds: 3));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(server.sockets.clients, isEmpty);
    });

    test('handles the actions that come during an onConnect', () async {
      server = await Server.start(
        configure: (app, sockets) =>
            app.configure(SlowController(sockets).configureServer),
      );
      var client = c.WebSockets(server.ws);
      var pong = next(client, 'pong');
      // Sent once it connects, while onConnect runs.
      client.sendAction(c.WebSocketAction(eventName: 'ping'));
      await client.connect();
      expect((await pong)?.data, 1);
      await client.close();
    });

    test('ignores the data of a socket that has closed', () async {
      server = await Server.start();
      var severe = <String>[];
      server.app.logger.onRecord
          .where((r) => r.level >= Level.SEVERE)
          .listen((r) => severe.add(r.message));
      var socket = server.sockets.onConnection.first;
      var client = await server.client();
      var context = await socket.timeout(const Duration(seconds: 3));
      await context.close();
      await server.sockets.handleData(context, '{"eventName": "late"}');
      expect(severe, isEmpty);
      await client.close();
    });

    test('sends the result of a service that does not broadcast', () async {
      server = await Server.start(create: (app) => _Unwired(app));
      server.app.use('/api/todos', MapService());
      var client = await server.client();
      var created = next(client, 'api/todos::created');
      await client.service('api/todos').create({'text': 'mine'});
      expect((await created)?.data, containsPair('text', 'mine'));
      await client.close();
    });

    test('batchEvent goes on when a client leaves in a filter', () async {
      server = await Server.start();
      var connections = Connections(server.sockets);
      var a = await server.client(), b = await server.client();
      await connections.reach(2);
      var leaving = server.sockets.clients.first;
      var got = next(b, 'news');
      await server.sockets.batchEvent(
        c.WebSocketEvent(eventName: 'news', data: 1),
        filter: (socket) async {
          if (identical(socket, leaving)) await socket.close();
          await Future.delayed(const Duration(milliseconds: 20));
          return true;
        },
      );
      expect((await got)?.data, 1);
      await a.close();
      await b.close();
    });

    test('sends with its serializer', () async {
      server = await Server.start(
        serializer: (data) => json.encode({...data as Map, 'by': 'serializer'}),
        configure: (app, sockets) =>
            sockets.onConnection.listen((socket) => socket.send('hello', 1)),
      );
      var client = c.WebSockets(server.ws);
      var data = client.onData.first;
      await client.connect();
      expect(
        json.decode(await data.timeout(const Duration(seconds: 3)) as String),
        containsPair('by', 'serializer'),
      );
      await client.close();
    });

    test('takes the data of a custom event that is not a map', () async {
      server = await Server.start();
      var errors = <Object?>[];
      var client = await server.client();
      client.onError.listen(errors.add);
      var got = server.sockets.onAction.first;
      client.sendAction(c.WebSocketAction(eventName: 'custom', data: [1, 2]));
      expect((await got.timeout(const Duration(seconds: 3))).data, [1, 2]);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(errors, isEmpty);
      await client.close();
    });
  });

  test('an action without an id or event name has none', () {
    var action = c.WebSocketAction.fromJson({'data': 1, 'params': 'x'});
    expect(action.id, isNull);
    expect(action.eventName, isNull);
    expect(action.params, isEmpty);
  });
}

class Todo {
  final String? text;

  Todo({this.text});
}

/// An [AngelWebSocket] that broadcasts the events of no service.
class _Unwired extends AngelWebSocket {
  _Unwired(super.app);

  @override
  void wireAllServices(Angel app) {}
}

/// A controller whose [onConnect] takes a while.
class SlowController extends WebSocketController {
  SlowController(super.ws);

  @override
  Future<void> onConnect(WebSocketContext socket) =>
      Future.delayed(const Duration(milliseconds: 200));

  @override
  void configureWs() {
    exposeWs('ping', (action, socket) => socket.send('pong', 1));
  }
}
