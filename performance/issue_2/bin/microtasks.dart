/// Counts the microtasks each request schedules, and times requests, through
/// `AngelHttp` with mock requests, so without sockets: a measure of the
/// framework's own future chain that a busy machine does not disturb.
///
/// ```sh
/// dart run bin/microtasks.dart
/// ```
library;

import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  for (var useZone in [false, true]) {
    var app = Angel(
      environment: const AngelEnvironment('production'),
      logger: Logger.detached('angel'),
    );
    // The routes of bin/angel.dart.
    app
      ..get('/', (req, res) {})
      ..get('/user/:id', (req, res) {
        res.write(req.params['id']);
      })
      ..post('/user', (req, res) {});
    var http = AngelHttp(app, useZone: useZone);
    app.optimizeForProduction();

    for (var (method, path) in [
      ('GET', '/'),
      ('GET', '/user/*'),
      ('POST', '/user'),
    ]) {
      var i = 0;
      Future<int> request() async {
        var rq = MockHttpRequest(
          method,
          Uri(path: path.replaceFirst('*', '${i++}')),
        );
        await rq.close();
        var count = 0;
        await runZoned(
          () => http.handleRequest(rq),
          zoneSpecification: ZoneSpecification(
            scheduleMicrotask: (self, parent, zone, f) {
              count++;
              parent.scheduleMicrotask(zone, f);
            },
          ),
        );
        await rq.response.drain<void>();
        return count;
      }

      var microtasks = 0;
      for (var n = 0; n < 2000; n++) {
        microtasks = await request();
      }
      var best = double.infinity;
      for (var round = 0; round < 5; round++) {
        var sw = Stopwatch()..start();
        for (var n = 0; n < 20000; n++) {
          await request();
        }
        best = [
          best,
          sw.elapsedMicroseconds / 20,
        ].reduce((a, b) => a < b ? a : b);
      }
      print(
        '${useZone ? 'zone   ' : 'no zone'}  ${'$method $path'.padRight(12)}'
        '  microtasks=$microtasks  ns/request=${best.toStringAsFixed(0)}',
      );
    }
  }
}
