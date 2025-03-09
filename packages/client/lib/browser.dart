/// Browser client library for the Angel framework.
library;

import 'dart:async' show Future, Stream, StreamController, Timer;
import 'dart:js_interop';
import 'package:web/web.dart';
import 'dart:convert';
import 'package:http/browser_client.dart' as http;
import 'angel3_client.dart';
import 'base_angel_client.dart';
export 'angel3_client.dart';

/// Queries an Angel server via REST.
class Rest extends BaseAngelClient {
  Rest(String basePath) : super(http.BrowserClient(), basePath);

  @override
  Future<AngelAuthResult> authenticate(
      {String? type, credentials, String authEndpoint = '/auth'}) async {
    if (type == null || type == 'token') {
      var storedToken = window.localStorage.getItem('token');
      if (storedToken == null) {
        throw Exception(
            'Cannot revive token from localStorage - there is none.');
      }

      var token = json.decode(storedToken);
      credentials ??= {'token': token};
    }

    final result = await super.authenticate(
        type: type, credentials: credentials, authEndpoint: authEndpoint);
    window.localStorage.setItem('token', json.encode(authToken = result.token));
    window.localStorage.setItem('user', json.encode(result.data));
    return result;
  }

  @override
  Stream<String> authenticateViaPopup(String url,
      {String eventName = 'token', String? errorMessage}) {
    var ctrl = StreamController<String>();
    var wnd = window.open(url, 'angel_client_auth_popup');

    //Timer t;
    //StreamSubscription? sub;
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!ctrl.isClosed) {
        if (wnd != null && wnd.closed) {
          ctrl.addError(AngelHttpException.notAuthenticated(
              message:
                  errorMessage ?? 'Authentication via popup window failed.'));
          ctrl.close();
          timer.cancel();
          //sub?.cancel();
        }
      } else {
        timer.cancel();
      }
    });

    EventListener? sub;
    window.addEventListener(
        eventName,
        sub = (ev) {
          var e = ev as CustomEvent;
          if (!ctrl.isClosed) {
            ctrl.add(e.detail.toString());
            //t.cancel();
            ctrl.close();
            //sub!.cancel();
            window.removeEventListener(eventName, sub);
          }
        }.toJS);

    /* With dart:html
    sub = window.on[eventName].listen((Event ev) {
      var e = ev as CustomEvent;
      if (!ctrl.isClosed) {
        ctrl.add(e.detail.toString());
        t.cancel();
        ctrl.close();
        sub!.cancel();
      }
    });
    */
    return ctrl.stream;
  }

  @override
  Future logout() {
    window.localStorage.removeItem('token');
    return super.logout();
  }
}
