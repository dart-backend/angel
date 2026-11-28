import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';

/// An app for runner_test.dart, which runs it as a process with a given
/// `ANGEL_ENV`: it prints the environment of its instance.
Future<void> app(Angel app) async {
  print('environment: ${app.environment.value}');
}

Future<void> main(List<String> args) => Runner('env', app).run(args);
