/// Times `Router.resolveAbsolute` without its cache, as a request with a path
/// not seen before resolves it: the routes of issue 2 among 20 more of a
/// typical API. Prints the best of five runs, in nanoseconds per resolution.
library;

import 'package:angel3_route/angel3_route.dart';

void main() {
  var router = Router<int>();
  for (var resource in ['users', 'posts', 'comments', 'tags', 'orders']) {
    router
      ..get(resource, 0)
      ..post(resource, 0)
      ..get('$resource/:id', 0)
      ..get('$resource/:id/history', 0);
  }
  router
    ..get('', 1)
    ..get('user/:id', 2)
    ..post('user', 3);

  var cases = {
    'GET /': ('GET', ''),
    'GET /user/:id': ('GET', 'user/*'),
    'POST /user': ('POST', 'user'),
    'GET /orders/:id/history': ('GET', 'orders/*/history'),
    'GET /nope (404)': ('GET', 'nope/*'),
  };

  const n = 200000;
  for (var MapEntry(key: name, value: (method, path)) in cases.entries) {
    var best = double.infinity;
    for (var run = 0; run < 5; run++) {
      var clock = Stopwatch()..start();
      var found = 0;
      for (var i = 0; i < n; i++) {
        var p = path.replaceFirst('*', '$i');
        found += router.resolveAbsolute(p, method: method, strip: false).length;
      }
      var ns = clock.elapsedMicroseconds * 1000 / n;
      if (ns < best) best = ns;
      if (found < 0) print(found);
    }
    print('${name.padRight(26)} ${best.toStringAsFixed(0).padLeft(6)} ns');
  }
}
