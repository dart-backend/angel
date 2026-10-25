import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';

/// An app for runner_test.dart, which runs it as a process: it must exit as
/// soon as its instance has closed on SIGINT, well before [shutdownTimeout].
const shutdownTimeout = Duration(seconds: 30);

Future<void> app(Angel app) async {
  app.get('/', (req, res) => 'ok');
}

Future<void> main(List<String> args) =>
    Runner('stop', app, shutdownTimeout: shutdownTimeout).run(args);
