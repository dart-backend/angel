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
    FutureOr<void> Function(Angel app, AngelWebSocket sockets)? configure,
  }) async {
    var app = Angel(reflector: reflector);
    var sockets = AngelWebSocket(
      app,
      allowedOrigins: allowedOrigins,
      allowedProtocols: allowedProtocols,
      serializer: serializer,
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

    test('does not reconnect once closed', () async {
      var connections = 0;
      server.sockets.onConnection.listen((_) => connections++);
      var client = await server.client(
        reconnectInterval: const Duration(milliseconds: 50),
      );
      await client.close();
      await Future.delayed(const Duration(milliseconds: 300));
      expect(connections, 1);
    });

    test('reconnects once when the server closes it', () async {
      var connections = 0;
      server.sockets.onConnection.listen((_) => connections++);
      var client = await server.client(
        reconnectInterval: const Duration(milliseconds: 50),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      await server.sockets.clients.single.close();
      await Future.delayed(const Duration(milliseconds: 500));
      expect(connections, 2);
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
