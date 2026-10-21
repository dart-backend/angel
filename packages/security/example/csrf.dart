import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_security/angel3_security.dart';
import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:logging/logging.dart';

/// Serves a form protected against CSRF on http://localhost:3000.
void main() async {
  Logger.root.onRecord.listen(prettyLog);

  var app = Angel(logger: Logger('csrf'));
  var http = AngelHttp(app);

  // In production, read the key from the configuration, and keep the cookie
  // `Secure` (served over HTTPS).
  var signer = CookieSigner.fromStringKey(
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ab',
  );
  var csrf = CsrfFilter(
    signer,
    allowedOrigins: {'http://localhost:3000'},
    secureCookie: false,
  );

  // Every request gets a token; those that change state must send it back.
  app.fallback(csrf.handleRequest);

  // A form sends the token in the `_csrf` field.
  app.get('/', (req, res) {
    var token = req.container!.make<CsrfToken>().value;
    res
      ..headers['content-type'] = 'text/html; charset=utf-8'
      ..write('''
<!DOCTYPE html>
<form method="post" action="/greet">
  <input type="hidden" name="_csrf" value="$token">
  <input name="name" placeholder="Your name">
  <button>Greet</button>
</form>
<!-- A script sends the token in the X-XSRF-TOKEN header: the value of the
     XSRF-TOKEN cookie, or the token of this page. -->
<button onclick="fetch('/greet', {method: 'POST',
  headers: {'X-XSRF-TOKEN': '$token', 'Content-Type': 'application/json'},
  body: JSON.stringify({name: 'fetch'})})
  .then(r => r.text()).then(alert)">Greet with fetch</button>
''');
  });

  app.post('/greet', (req, res) async {
    await req.parseBody();
    return 'Hello, ${req.bodyAsMap['name']}!';
  });

  await http.startServer(InternetAddress.loopbackIPv4, 3000);
  print('Listening at ${http.uri}');
}
