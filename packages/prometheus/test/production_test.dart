import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';
import 'package:angel3_prometheus/angel3_prometheus.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// The first metrics port; instance #n serves its metrics on this + n.
const metricsBase = 19100;

/// The app of each instance, top-level, so that isolates can run it.
Future<void> configureServer(Angel app) async {
  var metrics = PrometheusMetrics();
  await app.configure(metrics.configureServer);
  app.get('/hello', (req, res) => 'hello');
  var id = app.container.make<InstanceInfo>().id;
  await metrics.serve(app, InternetAddress.loopbackIPv4, metricsBase + id);
}

double countOf(String text) =>
    LineSplitter.split(text)
        .where((l) => l.startsWith('http_request_duration_seconds_count{'))
        .map((l) => double.parse(l.split(' ').last))
        .fold(0, (a, b) => a + b);

Future<bool> isFree(int port) async {
  try {
    await (await ServerSocket.bind(InternetAddress.loopbackIPv4, port)).close();
    return true;
  } on SocketException {
    return false;
  }
}

void main() {
  test('each instance of angel3_production serves its own metrics', () async {
    if (!await isFree(metricsBase) || !await isFree(metricsBase + 1)) {
      markTestSkipped('ports $metricsBase and ${metricsBase + 1} are in use');
      return;
    }
    var lines = <String>[];
    var runner = Runner('app', configureServer);
    await runZoned(
      () async {
        var running = runner.run(['-j', '2', '-p', '0']);
        var deadline = DateTime.now().add(const Duration(seconds: 20));
        while (lines.where((l) => l.contains('listening at')).length < 2) {
          if (DateTime.now().isAfter(deadline)) fail(lines.join('\n'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        var url = RegExp(r'listening at (\S+)').firstMatch(
          lines.join('\n').replaceAll(RegExp('\x1B\\[[0-9;]*m'), ''),
        )![1]!;
        for (var i = 0; i < 20; i++) {
          var client = http.Client();
          await client.get(Uri.parse(url).replace(path: '/hello'));
          client.close();
        }
        var total = 0.0;
        for (var id in [0, 1]) {
          var metrics = await http.get(
            Uri.parse('http://127.0.0.1:${metricsBase + id}/metrics'),
          );
          expect(metrics.statusCode, 200);
          total += countOf(metrics.body);
        }
        expect(total, 20);

        runner.stop();
        await running.timeout(const Duration(seconds: 15));
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    // Closed with the instances, so a later run can serve them again.
    expect(await isFree(metricsBase), isTrue);
    expect(await isFree(metricsBase + 1), isTrue);
  });
}
