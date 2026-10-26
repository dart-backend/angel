/// Browser WebSocket client library for the Angel framework.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:angel3_client/angel3_client.dart';
import 'package:http/browser_client.dart' as http;
import 'package:web/web.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';

import 'base_websocket_client.dart';
export 'angel3_websocket.dart';

final RegExp _straySlashes = RegExp(r'(^/)|(/+$)');

/// Queries an Angel server via WebSockets.
class WebSockets extends BaseWebSocketClient {
  WebSockets(String baseUrl, {super.reconnectOnClose, super.reconnectInterval})
    : super(http.BrowserClient(), baseUrl);

  @override
  Stream<String> authenticateViaPopup(
    String url, {
    String eventName = 'token',
    String? errorMessage,
  }) {
    var ctrl = StreamController<String>();
    var wnd = window.open(url, 'angel_client_auth_popup');
    Timer? timer;
    late JSFunction listener;

    void done() {
      timer?.cancel();
      window.removeEventListener(eventName, listener);
      ctrl.close();
    }

    // The token, of the event the popup fires on this window.
    listener = ((Event e) {
      if (ctrl.isClosed) return;
      ctrl.add((e as CustomEvent).detail.toString());
      done();
    }).toJS;
    window.addEventListener(eventName, listener);

    timer = Timer.periodic(Duration(milliseconds: 500), (_) {
      if (ctrl.isClosed) return;
      if (wnd != null && wnd.closed) {
        ctrl.addError(
          AngelHttpException.notAuthenticated(
            message: errorMessage ?? 'Authentication via popup window failed.',
          ),
        );
        done();
      }
    });

    return ctrl.stream;
  }

  @override
  Future<WebSocketChannel> getConnectedWebSocket() {
    var url = websocketUri;

    if (authToken?.isNotEmpty == true) {
      url = url.replace(
        queryParameters: Map<String, String?>.from(url.queryParameters)
          ..['token'] = authToken,
      );
    }

    var socket = WebSocket(url.toString());
    var completer = Completer<WebSocketChannel>();

    socket
      ..onOpen.listen((_) {
        if (!completer.isCompleted) {
          return completer.complete(HtmlWebSocketChannel(socket));
        }
      })
      ..onError.listen((Event e) {
        if (!completer.isCompleted) {
          return completer.completeError(
            e.isA<ErrorEvent>() ? (e as ErrorEvent).message : e,
          );
        }
      });

    return completer.future;
  }

  @override
  Service<Id, Data> service<Id, Data>(
    String path, {
    Type? type,
    AngelDeserializer<Data>? deserializer,
  }) {
    var uri = path.replaceAll(_straySlashes, '');
    return addService<Id, Data>(
      BrowserWebSocketsService<Id, Data>(
        socket,
        this,
        uri,
        type: type,
        deserializer: deserializer,
      ),
    );
  }
}

class BrowserWebSocketsService<Id, Data> extends WebSocketsService<Id, Data> {
  final Type? type;

  BrowserWebSocketsService(
    super.socket,
    WebSockets super.app,
    super.uri, {
    this.type,
    super.deserializer,
  });
}
