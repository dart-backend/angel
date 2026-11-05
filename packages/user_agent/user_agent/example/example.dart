import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_user_agent/angel3_user_agent.dart';

/// Tells visitors of http://localhost:3000 whether they run Chrome, Edge or Opera.
void main() async {
  var app = Angel();
  var http = AngelHttp(app);

  app.get(
    '/',
    chain([
      parseUserAgent,
      (req, res) {
        var ua = req.container!.make<UserAgent>();
        // Edge and Opera are built on Chromium, but are not Chrome.
        return ua.isChrome || ua.isEdge || ua.isOpera
            ? 'Woohoo! You are running Chrome, Edge or Opera.'
            : 'Sorry, we only support Chrome, Edge and Opera.';
      },
    ]),
  );

  var server = await http.startServer(InternetAddress.loopbackIPv4, 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
