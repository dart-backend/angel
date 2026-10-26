import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';

/// An app for runner_test.dart, which runs it as a process: two runs at
/// once, which one SIGINT must close gracefully.
Future<void> app(Angel app) async {
  app.shutdownHooks.add((_) => print('closed instance'));
  app.get('/', (req, res) => 'ok');
}

Future<void> main(List<String> args) async {
  var runner = Runner('two', app);
  await Future.wait([runner.run(args), runner.run(args)]);
}
