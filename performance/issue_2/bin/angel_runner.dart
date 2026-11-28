/// The Angel3 app of issue 2, served by `angel3_production`'s [Runner]
/// instead of isolates spawned by hand, as `bin/angel.dart` does.
///
/// It runs with the runner's defaults (production mode, no zone per request,
/// respawning, logging to the main isolate), but on all addresses, as
/// `bin/angel.dart` does, with `ISOLATES` instances on `PORT`.
library;

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';

import 'env.dart';

Future<void> configureServer(Angel app) async {
  app.get('/', (req, res) {});

  app.get('/user/:id', (req, res) {
    res.write(req.params['id']);
  });

  app.post('/user', (req, res) {});
}

Future<void> main() => Runner('angel_runner', configureServer).run([
  '--address',
  '0.0.0.0',
  '--port',
  '$port',
  '--concurrency',
  '$isolateCount',
]);
