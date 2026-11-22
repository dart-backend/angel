# Change Log

## 10.0.0

### New in 10.0.0

* **Metrics:** `PrometheusMetrics` times each request from its start to the end of its response, as `http_request_duration_seconds` by `method` and status `code`, counts the requests in progress as `http_requests_in_progress`, and adds the metrics of the Dart process of `prometheus_client`. `ignore` leaves out requests such as health checks, and an app adds metrics of its own to `registry`
* **Middleware:** `configureServer` measures every request, of a middleware that matches every path, but keeps the `404 Not Found` of a path that no other route matches, where such a middleware makes it an empty `200`. It warns when configured after other routes, which it does not measure
* **Serving:** `serve` answers `GET /metrics` in the Prometheus text format on a server of its own, closed when the app closes, such as one port for each instance of `angel3_production`. `handler` serves them on a route of the app, and `collect` gives them as text
