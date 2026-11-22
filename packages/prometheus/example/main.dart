import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_prometheus/angel3_prometheus.dart';

Future<void> main() async {
  var app = Angel();
  var metrics = PrometheusMetrics(ignore: (req) => req.path == 'health');

  // First, so that it measures every request.
  await app.configure(metrics.configureServer);

  // A metric of the app's own.
  var greetings = Counter(name: 'greetings_total', help: 'Greetings sent.')
    ..register(metrics.registry);

  app
    ..get('/hello', (req, res) {
      greetings.inc();
      return 'Hello!';
    })
    ..get('/health', (req, res) => 'up');

  // The metrics, at http://127.0.0.1:9100/metrics, off the app's port.
  await metrics.serve(app, InternetAddress.loopbackIPv4, 9100);

  var http = AngelHttp(app);
  await http.startServer('127.0.0.1', 3000);
  print('Listening at ${http.uri}; metrics at http://127.0.0.1:9100/metrics');
}
