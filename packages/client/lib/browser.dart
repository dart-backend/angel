/// Browser client library for the Angel framework.
library;

import 'dart:async'
    show Future, Stream, StreamController, StreamSubscription, Timer;
import 'dart:html' show CustomEvent, Event, window;
import 'dart:convert';
import 'package:http/browser_client.dart' as http;
import 'angel3_client.dart';
// import 'auth_types.dart' as auth_types;
import 'base_angel_client.dart';
export 'angel3_client.dart';

/// Queries an Angel server via REST.
class Rest extends BaseAngelClient {
  Rest(String basePath) : super(http.BrowserClient(), basePath);

  @override
  Future<AngelAuthResult> authenticate(
      {String? type, credentials, String authEndpoint = '/auth'}) async {
    if (type == null || type == 'token') {
      if (!window.localStorage.containsKey('token')) {
        throw Exception(
            'Cannot revive token from localStorage - there is none.');
      }

      var token = json.decode(window.localStorage['token']!);
      credentials ??= {'token': token};
    }

    final result = await super.authenticate(
        type: type, credentials: credentials, authEndpoint: authEndpoint);
    window.localStorage['token'] = json.encode(authToken = result.token);
    window.localStorage['user'] = json.encode(result.data);
    return result;
  }

  @override
  Stream<String> authenticateViaPopup(String url,
      {String eventName = 'token', String? errorMessage}) {
    var ctrl = StreamController<String>();
    var wnd = window.open(url, 'angel_client_auth_popup');

    Timer t;
    StreamSubscription? sub;
    t = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!ctrl.isClosed) {
        if (wnd.closed!) {
          ctrl.addError(AngelHttpException.notAuthenticated(
              message:
                  errorMessage ?? 'Authentication via popup window failed.'));
          ctrl.close();
          timer.cancel();
          sub?.cancel();
        }
      } else {
        timer.cancel();
      }
    });

    sub = window.on[eventName].listen((Event ev) {
      var e = ev as CustomEvent;
      if (!ctrl.isClosed) {
        ctrl.add(e.detail.toString());
        t.cancel();
        ctrl.close();
        sub!.cancel();
      }
    });

    return ctrl.stream;
  }

  @override
  Future logout() {
    window.localStorage.remove('token');
    return super.logout();
  }
}
