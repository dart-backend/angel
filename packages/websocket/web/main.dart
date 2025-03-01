import 'package:angel3_websocket/browser.dart';
import 'package:web/web.dart';

/// Dummy app to ensure client works with DDC.
void main() {
  var app = WebSockets(window.location.origin);
  window.alert(app.baseUrl.toString());

  // ignore: body_might_complete_normally_catch_error
  app.connect().catchError((_) {
    window.alert('no websocket');
  });
}
