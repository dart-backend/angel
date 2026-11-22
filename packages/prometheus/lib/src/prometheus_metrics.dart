import 'dart:async';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:http_parser/http_parser.dart';
import 'package:prometheus_client/format.dart' as format;
import 'package:prometheus_client/prometheus_client.dart';
import 'package:prometheus_client/runtime_metrics.dart' as runtime_metrics;

/// Metrics of the requests of an Angel3 app, for Prometheus.
///
/// Configure it before the app's routes, so that it sees every request:
///
/// ```dart
/// var metrics = PrometheusMetrics();
/// await app.configure(metrics.configureServer);
/// // ... routes ...
/// await metrics.serve(app, InternetAddress.loopbackIPv4, 9100);
/// ```
///
/// It keeps these, in [registry]:
///
/// * `http_request_duration_seconds`, a histogram of the time from the
///   start of a request to the end of its response, by `method` and `code`
///   (the status code). Its `_count` counts the requests.
/// * `http_requests_in_progress`, a gauge of the requests whose response is
///   still open.
/// * With `runtimeMetrics`, those of the Dart process: `dart_info`,
///   `process_resident_memory_bytes` and `process_start_time_seconds`.
///
/// A request whose response is detached, as of a WebSocket, is not timed.
class PrometheusMetrics {
  /// The registry of the metrics, to which an app may add its own.
  final CollectorRegistry registry;

  /// `http_request_duration_seconds`, by `method` and `code`.
  final Histogram requestDuration;

  /// `http_requests_in_progress`.
  late final Gauge requestsInProgress;

  /// Whether a request is left out of the metrics, such as a health check.
  final bool Function(RequestContext req)? ignore;

  final Set<ResponseContext> _open = {};

  /// Metrics of a new [CollectorRegistry], unless [registry] is given.
  ///
  /// [buckets] are the upper bounds, in seconds, of the buckets of
  /// [requestDuration].
  PrometheusMetrics({
    CollectorRegistry? registry,
    bool runtimeMetrics = true,
    List<double> buckets = Histogram.defaultBuckets,
    this.ignore,
  }) : registry = registry ?? CollectorRegistry(),
       requestDuration = Histogram(
         name: 'http_request_duration_seconds',
         help:
             'The time from the start of a request to the end of its '
             'response.',
         labelNames: ['method', 'code'],
         buckets: buckets,
       ) {
    requestsInProgress = Gauge(
      name: 'http_requests_in_progress',
      help: 'The requests whose response is still open.',
      // A detached response never completes `done`: it is no longer open.
      collectCallback: (gauge) {
        _open.removeWhere((res) => !res.isOpen);
        gauge.value = _open.length.toDouble();
      },
    );
    requestDuration.register(this.registry);
    requestsInProgress.register(this.registry);
    if (runtimeMetrics) runtime_metrics.register(this.registry);
  }

  /// Adds the middleware that measures each request to [app].
  ///
  /// Configure it before the app's routes: a route that answers before it
  /// runs is not measured. It matches every path, but answers a path that
  /// no other route matches with `404 Not Found`, as the app did without it.
  FutureOr<void> configureServer(Angel app) {
    if (app.routes.isNotEmpty) {
      app.logger.warning(
        'PrometheusMetrics is configured after other routes, so requests '
        'that they answer first are not measured.',
      );
    }
    late RequestHandler middleware;
    middleware = (req, res) {
      // Only this handler matched: the app answers 404, as it would have
      // without it, rather than an empty 200.
      var pipeline = req.container?.has<MiddlewarePipeline>() == true
          ? req.container!.make<MiddlewarePipeline>()
          : null;
      var notFound =
          pipeline != null &&
          pipeline.handlers.every((h) => identical(h, middleware));
      if (ignore?.call(req) != true) _measure(req, res);
      if (notFound) throw AngelHttpException.notFound();
      return true;
    };
    app.all('*', middleware);
  }

  void _measure(RequestContext req, ResponseContext res) {
    var watch = Stopwatch()..start();
    _open.add(res);
    res.done.catchError((_) {}).whenComplete(() {
      _open.remove(res);
      requestDuration
          .labels([req.method, '${res.statusCode}'])
          .observe(watch.elapsedMicroseconds / Duration.microsecondsPerSecond);
    });
  }

  /// The metrics of [registry], in the Prometheus text format.
  Future<String> collect() async {
    var buffer = StringBuffer();
    format.write004(buffer, await registry.collectMetricFamilySamples());
    return buffer.toString();
  }

  /// A handler that answers with the metrics, for a route such as
  /// `app.get('/metrics', metrics.handler)`. Prefer [serve], which keeps
  /// them off the app's own port.
  RequestHandler get handler => (req, res) async {
    res.contentType = MediaType.parse(format.contentType);
    res.write(await collect());
    return false;
  };

  /// Serves the metrics at `GET /metrics` of a server of its own, on
  /// [address] and [port], which [app] closes when it closes.
  ///
  /// With `angel3_production`, give each instance a port of its own, such
  /// as `9100 + app.container.make<InstanceInfo>().id`, for Prometheus to
  /// scrape each: the instances share the app's port, so a scrape of it
  /// would reach one instance only.
  Future<HttpServer> serve(Angel app, Object address, int port) async {
    var server = await HttpServer.bind(address, port);
    server.listen((request) async {
      var response = request.response;
      try {
        if (request.method != 'GET' || request.uri.path != '/metrics') {
          response.statusCode = HttpStatus.notFound;
        } else {
          response.headers.contentType = ContentType.parse(format.contentType);
          response.write(await collect());
        }
      } catch (e, st) {
        app.logger.severe('Failed to collect the metrics', e, st);
        response.statusCode = HttpStatus.internalServerError;
      }
      await response.close();
    });
    app.shutdownHooks.add((_) => server.close(force: true));
    return server;
  }
}
