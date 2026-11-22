# Angel3 Prometheus

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_prometheus?include_prereleases)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/prometheus/LICENSE)

[Prometheus](https://prometheus.io/) metrics for Angel3 applications: it times each request by its method and status code, counts the requests in progress, and serves the metrics in the Prometheus text format, for Prometheus to scrape and Grafana to chart. It is built on [prometheus_client](https://pub.dev/packages/prometheus_client), so an app can add metrics of its own.

- [Installation](#installation)
- [Usage](#usage)
  - [The metrics](#the-metrics)
  - [Metrics of your own](#metrics-of-your-own)
- [With angel3\_production](#with-angel3_production)
  - [Scraping the instances](#scraping-the-instances)
  - [Queries](#queries)
- [Things to know](#things-to-know)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_framework: ^10.2.0
  angel3_prometheus: ^10.0.0
```

## Usage

Configure `PrometheusMetrics` before the app's routes, so that it sees every request, and serve the metrics on a port of their own:

```dart
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_prometheus/angel3_prometheus.dart';

Future<void> main() async {
  var app = Angel();
  var metrics = PrometheusMetrics(ignore: (req) => req.path == 'health');
  await app.configure(metrics.configureServer);

  app
    ..get('/hello', (req, res) => 'Hello!')
    ..get('/health', (req, res) => 'up');

  // http://127.0.0.1:9100/metrics
  await metrics.serve(app, InternetAddress.loopbackIPv4, 9100);

  await AngelHttp(app).startServer('0.0.0.0', 3000);
}
```

`serve` answers `GET /metrics` on a server of its own, which closes when the app closes. Bind it to an address that only Prometheus reaches, such as the loopback or an internal interface, so that the metrics aren't public. To serve them on the app's port instead, add a route of `metrics.handler`: `app.get('/metrics', metrics.handler)`.

### The metrics

| Metric | Type | Labels | What it is |
| --- | --- | --- | --- |
| `http_request_duration_seconds` | histogram | `method`, `code` | The time from the start of a request to the end of its response. Its `_count` counts the requests, and `code` is the status code, so it also counts the failures. |
| `http_requests_in_progress` | gauge | | The requests whose response is still open. |
| `dart_info` | gauge | `version` | The Dart version. Leave out these three with `runtimeMetrics: false`. |
| `process_resident_memory_bytes` | gauge | | The memory of the process. |
| `process_start_time_seconds` | gauge | | When the process started. |

Options of `PrometheusMetrics`:

- **`registry`**: the `CollectorRegistry` of the metrics. By default a new one, rather than `CollectorRegistry.defaultRegistry`, so that two apps of one isolate don't share it.
- **`buckets`**: the upper bounds, in seconds, of the histogram's buckets. By default those of `Histogram.defaultBuckets`, from 5 ms to 10 s.
- **`ignore`**: the requests to leave out, such as health checks. They are still answered as usual.
- **`runtimeMetrics`**: whether to add the metrics of the Dart process, `true` by default.

### Metrics of your own

Register them in `metrics.registry`, and they are served with the others:

```dart
var logins = Counter(name: 'logins_total', help: 'Successful logins.')
  ..register(metrics.registry);

app.post('/login', (req, res) {
  // ... sign the user in ...
  logins.inc();
  return true;
});
```

## With angel3_production

[angel3_production](https://pub.dev/packages/angel3_production) runs the app in several isolates that share its port, each with metrics of its own. A scrape of the shared port would reach one instance at random, so serve the metrics of each instance on a port of its own, from its `InstanceInfo`:

```dart
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';
import 'package:angel3_prometheus/angel3_prometheus.dart';

void main(List<String> args) => Runner('example', configureServer).run(args);

Future<void> configureServer(Angel app) async {
  var metrics = PrometheusMetrics();
  await app.configure(metrics.configureServer);

  app.get('/hello', (req, res) => 'Hello!');

  // Last: instance #0 serves its metrics on 9100, #1 on 9101, and so on.
  var instance = app.container.make<InstanceInfo>();
  await metrics.serve(app, InternetAddress.loopbackIPv4, 9100 + instance.id);
}
```

Call `serve` last in `configureServer`. An instance that fails to start exits its isolate without closing the app, and a port that the isolate has bound stays bound to the process, so an instance started again in its place could not bind it.

### Scraping the instances

Give Prometheus a target for each instance, one for each of `--concurrency`:

```yaml
scrape_configs:
  - job_name: angel3
    static_configs:
      - targets: ['127.0.0.1:9100', '127.0.0.1:9101', '127.0.0.1:9102', '127.0.0.1:9103']
```

### Queries

Add the instances up with `sum`. For Grafana panels:

| Panel | PromQL |
| --- | --- |
| Requests per second | `sum(rate(http_request_duration_seconds_count[1m]))` |
| Requests per second, by status | `sum by (code) (rate(http_request_duration_seconds_count[1m]))` |
| Failures per second | `sum(rate(http_request_duration_seconds_count{code=~"5.."}[1m]))` |
| Average response time | `sum(rate(http_request_duration_seconds_sum[5m])) / sum(rate(http_request_duration_seconds_count[5m]))` |
| 95th percentile response time | `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))` |
| Requests in progress | `sum(http_requests_in_progress)` |
| Memory | `max(process_resident_memory_bytes)` |

The instances are isolates of one process, so each gives the same `process_resident_memory_bytes`: take its `max`, not its `sum`.

## Things to know

- **Configure it first.** A route registered before it that answers a request ends the request before it is measured. It logs a warning if the app has routes already.
- **404s are kept.** It matches every path, as a middleware must, but answers a path that no other route matches with `404 Not Found`, as the app did without it. (A middleware of your own of `app.all('*', ...)` or `app.fallback(...)` that returns `true` makes such a path an empty `200`, unless a last `app.fallback((req, res) => throw AngelHttpException.notFound())` answers it.)
- **Detached responses**, such as those of WebSockets, are not timed, and are not counted as in progress once detached.
- **CPU** is not among the metrics of the Dart process. Use the [node exporter](https://github.com/prometheus/node_exporter), or cAdvisor for containers, for the CPU and memory of the machine.
- **Labels.** Keep their values few: a label of a user id, or of a path with ids in it, makes a time series of each value. Count users, such as those of a day, in your logs or analytics.
- **prometheus_client** was last released in 2022, and is null-safe, so Dart 3 runs it.
