import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:angel3_client/base_angel_client.dart' as client;
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_websocket/io.dart' as client;
import 'package:http/http.dart' as http hide StreamedResponse;
import 'package:http/http.dart';
import 'package:http/io_client.dart' as http;
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
//import 'package:uuid/uuid.dart';

final RegExp _straySlashes = RegExp(r'(^/)|(/+$)');
/*const Map<String, String> _readHeaders = const {'Accept': 'application/json'};
const Map<String, String> _writeHeaders = const {
  'Accept': 'application/json',
  'Content-Type': 'application/json'
};
final Uuid _uuid =  Uuid();*/

/// Shorthand for bootstrapping a [TestClient].
Future<TestClient> connectTo(Angel app,
    {Map? initialSession,
    bool autoDecodeGzip = true,
    bool useZone = false}) async {
  print('Load configuration');
  if (!app.environment.isProduction) {
    app.configuration.putIfAbsent('testMode', () => true);
  }

  for (var plugin in app.startupHooks) {
    print('Load plugins');
    await plugin(app);
  }
  return TestClient(app,
      autoDecodeGzip: autoDecodeGzip != false, useZone: useZone)
    ..session.addAll(initialSession ?? {});
}

/// An `angel_client` that sends mock requests to a server, rather than actual HTTP transactions.
class TestClient extends client.BaseAngelClient {
  final Map<String, client.Service> _services = {};

  /// Session info to be sent to the server on every request.
  final HttpSession session = MockHttpSession(id: 'angel-test-client');

  /// A list of cookies to be sent to and received from the server.
  final List<Cookie> cookies = [];

  /// If `true` (default), the client will automatically decode GZIP response bodies.
  final bool autoDecodeGzip;

  /// The server instance to mock.
  final Angel server;

  late AngelHttp _http;

  TestClient(this.server, {this.autoDecodeGzip = true, bool useZone = false})
      : super(http.IOClient(), '/') {
    _http = AngelHttp(server, useZone: useZone);
  }

  @override
  Future close() {
    this.client.close();
    return server.close();
  }

  /// Opens a WebSockets connection to the server. This will automatically bind the server
  /// over HTTP, if it is not already listening. Unfortunately, WebSockets cannot be mocked (yet!).
  Future<client.WebSockets> websocket(
      {String path = '/ws', Duration? timeout}) async {
    if (_http.server == null) await _http.startServer();
    var url = _http.uri.replace(scheme: 'ws', path: path);
    var ws = _MockWebSockets(this, url.toString());
    await ws.connect(timeout: timeout);
    return ws;
  }

  @override
  Future<StreamedResponse> send(http.BaseRequest request) async {
    var rq = MockHttpRequest(request.method, request.url);
    request.headers.forEach(rq.headers.add);

    if (request.url.userInfo.isNotEmpty) {
      // Attempt to send as Basic auth
      var encoded = base64Url.encode(utf8.encode(request.url.userInfo));
      rq.headers.add('authorization', 'Basic $encoded');
    } else if (rq.headers.value('authorization')?.startsWith('Basic ') ==
        true) {
      var encoded = rq.headers.value('authorization')!.substring(6);
      var decoded = utf8.decode(base64Url.decode(encoded));
      var oldRq = rq;
      var newRq = MockHttpRequest(rq.method, rq.uri.replace(userInfo: decoded));
      oldRq.headers.forEach(newRq.headers.add);
      rq = newRq;
    }

    if (authToken?.isNotEmpty == true) {
      rq.headers.add('authorization', 'Bearer $authToken');
    }
    rq
      ..cookies.addAll(cookies)
      ..session.addAll(session);

    await request.finalize().pipe(rq);

    await _http.handleRequest(rq);

    var rs = rq.response;
    session
      ..clear()
      ..addAll(rq.session);

    var extractedHeaders = <String, String>{};

    rs.headers.forEach((k, v) {
      extractedHeaders[k] = v.join(',');
    });

    Stream<List<int>> stream = rs;

    if (autoDecodeGzip != false &&
        rs.headers['content-encoding']?.contains('gzip') == true) {
      stream = stream.transform(gzip.decoder);
    }

    // Calling persistentConnection causes LateInitialization Exception
    //var keepAliveState = rq.headers?.persistentConnection;
    //if (keepAliveState == null) {
    //  keepAliveState = false;
    //}

    return StreamedResponse(stream, rs.statusCode,
        contentLength: rs.contentLength,
        isRedirect: rs.headers['location'] != null,
        headers: extractedHeaders,
        persistentConnection:
            rq.headers.value('connection')?.toLowerCase().trim() ==
                'keep-alive',
        //|| keepAliveState,
        reasonPhrase: rs.reasonPhrase);
  }

  //@override
  late String basePath;

  @override
  Stream<String> authenticateViaPopup(String url,
      {String eventName = 'token'}) {
    throw UnsupportedError(
        'MockClient does not support authentication via popup.');
  }

  @override
  Future configure(client.AngelConfigurer configurer) =>
      Future.sync(() => configurer(this));

  @override
  client.Service<Id, Data> service<Id, Data>(String path,
      {Type? type, client.AngelDeserializer<Data>? deserializer}) {
    var uri = path.toString().replaceAll(_straySlashes, '');
    return _services.putIfAbsent(uri,
            () => _MockService<Id, Data>(this, uri, deserializer: deserializer))
        as client.Service<Id, Data>;
  }
}

class _MockService<Id, Data> extends client.BaseAngelService<Id, Data> {
  final TestClient _app;

  _MockService(this._app, String basePath,
      {client.AngelDeserializer<Data>? deserializer})
      : super(_app, _app, basePath, deserializer: deserializer);

  @override
  Future<StreamedResponse> send(http.BaseRequest request) {
    if (app.authToken != null && app.authToken!.isNotEmpty) {
      request.headers['authorization'] ??= 'Bearer ${app.authToken}';
    }

    return _app.send(request);
  }
}

class _MockWebSockets extends client.WebSockets {
  final TestClient app;

  _MockWebSockets(this.app, String url) : super(url);

  @override
  Future<WebSocketChannel> getConnectedWebSocket() async {
    var headers = <String, String>{};

    if (app.authToken?.isNotEmpty == true) {
      headers['authorization'] = 'Bearer ${app.authToken}';
    }

    var socket = await WebSocket.connect(baseUrl.toString(), headers: headers);
    return IOWebSocketChannel(socket);
  }
}
