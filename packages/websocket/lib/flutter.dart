/// Flutter-compatible WebSocket client library for the Angel framework.
library;

import 'dart:async';
import 'dart:io';
import 'package:http/io_client.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'base_websocket_client.dart';
export 'package:angel3_client/angel3_client.dart';
export 'angel3_websocket.dart';

// final RegExp _straySlashes = RegExp(r"(^/)|(/+$)");

/// Queries an Angel server via WebSockets.
class WebSockets extends BaseWebSocketClient {
  final List<WebSocketsService> _services = [];

  WebSockets(baseUrl,
      {bool reconnectOnClose = true, Duration? reconnectInterval})
      : super(http.IOClient(), baseUrl,
            reconnectOnClose: reconnectOnClose,
            reconnectInterval: reconnectInterval);

  @override
  Stream<String> authenticateViaPopup(String url,
      {String eventName = 'token'}) {
    throw UnimplementedError(
        'Opening popup windows is not supported in the `dart:io` client.');
  }

  @override
  Future close() {
    for (var service in _services) {
      service.close();
    }

    return super.close();
  }

  @override
  Future<WebSocketChannel> getConnectedWebSocket() async {
    var socket = await WebSocket.connect(websocketUri.toString(),
        headers: authToken?.isNotEmpty == true
            ? {'Authorization': 'Bearer $authToken'}
            : {});
    return IOWebSocketChannel(socket);
  }
}
