import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_user_agent/angel3_user_agent.dart';

/// Tells visitors of http://localhost:3000 whether they run Chrome.
void main() async {
  var app = Angel();
  var http = AngelHttp(app);

  app.get(
    '/',
    chain([
      parseUserAgent,
      (req, res) {
        var ua = req.container!.make<UserAgent>();
        return ua.isChrome
            ? 'Woohoo! You are running Chrome.'
            : 'Sorry, we only support Google Chrome.';
      },
    ]),
  );

  var server = await http.startServer(InternetAddress.loopbackIPv4, 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
