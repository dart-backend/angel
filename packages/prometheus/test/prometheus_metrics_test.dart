import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:angel3_prometheus/angel3_prometheus.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// The status and body of a GET of [path] of [app].
Future<(int, String)> get(Angel app, String path) async {
  var rq = MockHttpRequest('GET', Uri.parse(path));
  await rq.close();
  await AngelHttp(app).handleRequest(rq);
  var body = await rq.response.transform(utf8.decoder).join();
  return (rq.response.statusCode, body);
}

/// The value of the sample [name] with [labels] in [text], or `null`.
///
/// `prometheus_client` writes a comma after the last label, as the text
/// format allows: `name{a="1",b="2",} 1.0`.
double? sample(String text, String name, [String labels = '']) {
  var line = LineSplitter.split(text).firstWhere(
    (l) => l.startsWith(labels.isEmpty ? '$name ' : '$name{$labels,} '),
    orElse: () => '',
  );
  return line.isEmpty ? null : double.parse(line.split(' ').last);
}

double? count(String text, String code) => sample(
  text,
  'http_request_duration_seconds_count',
  'method="GET",code="$code"',
);

/// An app of [metrics], with a few routes.
Future<Angel> appOf(PrometheusMetrics metrics) async {
  var app = Angel();
  await app.configure(metrics.configureServer);
  app
    ..get('/ok', (req, res) => 'ok')
    ..get('/boom', (req, res) => throw StateError('boom'))
    ..get('/denied', (req, res) => throw AngelHttpException.notAuthenticated())
    ..get('/health', (req, res) => 'up');
  return app;
}

void main() {
  late PrometheusMetrics metrics;
  late Angel app;

  setUp(() async {
    metrics = PrometheusMetrics(ignore: (req) => req.path == 'health');
    app = await appOf(metrics);
  });

  test('times each request by its status code', () async {
    await get(app, '/ok');
    await get(app, '/ok');
    await get(app, '/boom');
    await get(app, '/denied');
    var text = await metrics.collect();
    expect(count(text, '200'), 2);
    expect(count(text, '500'), 1);
    expect(count(text, '401'), 1);
    expect(
      sample(
        text,
        'http_request_duration_seconds_sum',
        'method="GET",code="200"',
      ),
      greaterThan(0),
    );
  });

  test('keeps the 404 of a path that no route matches', () async {
    var (status, body) = await get(app, '/missing');
    expect(status, 404);
    expect(body, contains('404'));
    expect(count(await metrics.collect(), '404'), 1);
    expect((await get(app, '/ok')).$1, 200);
  });

  test('leaves out the requests of ignore', () async {
    expect(await get(app, '/health'), (200, '"up"'));
    expect(count(await metrics.collect(), '200'), isNull);
  });

  test('counts the requests in progress', () async {
    var release = Completer<void>();
    app.get('/slow', (req, res) async {
      await release.future;
      return 'done';
    });
    var slow = get(app, '/slow');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sample(await metrics.collect(), 'http_requests_in_progress'), 1);
    release.complete();
    await slow;
    expect(sample(await metrics.collect(), 'http_requests_in_progress'), 0);
  });

  test('does not count a detached response as in progress', () async {
    app.get('/detached', (req, res) async {
      var raw = res.detach() as HttpResponse;
      raw.write('raw');
      await raw.close();
      return false;
    });
    expect((await get(app, '/detached')).$2, 'raw');
    var text = await metrics.collect();
    expect(sample(text, 'http_requests_in_progress'), 0);
    expect(count(text, '200'), isNull);
  });

  test('handler answers with the metrics', () async {
    app.get('/metrics', metrics.handler);
    await get(app, '/ok');
    var rq = MockHttpRequest('GET', Uri.parse('/metrics'));
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    var body = await rq.response.transform(utf8.decoder).join();
    expect(rq.response.headers.contentType?.mimeType, 'text/plain');
    expect(rq.response.headers.contentType?.parameters['version'], '0.0.4');
    expect(count(body, '200'), 1);
  });

  group('serve', () {
    test('serves GET /metrics on a port of its own', () async {
      var server = await metrics.serve(app, InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      await get(app, '/ok');
      var base = Uri.parse('http://127.0.0.1:${server.port}');
      var response = await http.get(base.replace(path: '/metrics'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], startsWith('text/plain'));
      expect(count(response.body, '200'), 1);
      expect(
        sample(response.body, 'process_resident_memory_bytes'),
        greaterThan(0),
      );
      expect((await http.get(base.replace(path: '/other'))).statusCode, 404);
      expect((await http.post(base.replace(path: '/metrics'))).statusCode, 404);
    });

    test('is closed when the app closes', () async {
      var driver = AngelHttp(app);
      await driver.startServer('127.0.0.1', 0);
      var server = await metrics.serve(app, InternetAddress.loopbackIPv4, 0);
      var port = server.port;
      await driver.close();
      var socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      await socket.close();
    });
  });

  test('runtimeMetrics: false leaves out those of the process', () async {
    var text = await PrometheusMetrics(runtimeMetrics: false).collect();
    expect(sample(text, 'process_resident_memory_bytes'), isNull);
    expect(sample(text, 'http_requests_in_progress'), 0);
  });

  test('warns when configured after other routes', () async {
    var app = Angel()..get('/ok', (req, res) => 'ok');
    var records = <String>[];
    app.logger.onRecord.listen((r) => records.add(r.message));
    await app.configure(PrometheusMetrics().configureServer);
    expect(records, [contains('configured after other routes')]);
  });

  test('an app may register its own metrics in registry', () async {
    var logins = Counter(name: 'logins_total', help: 'Logins.')
      ..register(metrics.registry);
    logins.inc();
    expect(sample(await metrics.collect(), 'logins_total'), 1);
  });
}
