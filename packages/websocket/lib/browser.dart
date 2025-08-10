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
  final List<BrowserWebSocketsService> _services = [];

  WebSockets(
    baseUrl, {
    bool reconnectOnClose = true,
    Duration? reconnectInterval,
  }) : super(
         http.BrowserClient(),
         baseUrl,
         reconnectOnClose: reconnectOnClose,
         reconnectInterval: reconnectInterval,
       );

  @override
  Future close() {
    for (var service in _services) {
      service.close();
    }

    return super.close();
  }

  @override
  Stream<String> authenticateViaPopup(
    String url, {
    String eventName = 'token',
    String? errorMessage,
  }) {
    var ctrl = StreamController<String>();
    var wnd = window.open(url, 'angel_client_auth_popup');

    //Timer t;
    //StreamSubscription<Event>? sub;
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!ctrl.isClosed) {
        if (wnd != null && wnd.closed) {
          ctrl.addError(
            AngelHttpException.notAuthenticated(
              message:
                  errorMessage ?? 'Authentication via popup window failed.',
            ),
          );
          ctrl.close();
          timer.cancel();
          //sub?.cancel();
        }
      } else {
        timer.cancel();
      }
    });

    // TODO: This need to be fixed
    EventListener? sub;
    window.addEventListener(
      eventName,
      (e) {
        if (!ctrl.isClosed) {
          ctrl.add((e as CustomEvent).detail.toString());
          //t.cancel();
          ctrl.close();
          //sub?.cancel();
          window.removeEventListener(eventName, sub);
        }
      }.toJS,
    );
    /* With dart:html
    sub = window.on[eventName].listen((e) {
      if (!ctrl.isClosed) {
        ctrl.add((e as CustomEvent).detail.toString());
        t.cancel();
        ctrl.close();
        sub?.cancel();
      }
    });
    */

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
      ..onError.listen((e) {
        if (!completer.isCompleted) {
          return completer.completeError(e is ErrorEvent ? e.error! : e);
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
    return BrowserWebSocketsService<Id, Data>(
          socket,
          this,
          uri,
          deserializer: deserializer,
        )
        as Service<Id, Data>;
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
