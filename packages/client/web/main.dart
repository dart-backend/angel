import 'package:web/web.dart';
import 'package:angel3_client/browser.dart';

/// Dummy app to ensure client works with DDC.
void main() {
  var app = Rest(window.location.origin);
  window.alert(app.baseUrl.toString());
}
