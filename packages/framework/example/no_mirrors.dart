/// An app that runs without `dart:mirrors`, so it can be AOT-compiled:
///
/// ```sh
/// dart compile exe example/no_mirrors.dart -o server
/// ```
library;

import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:logging/logging.dart';

class Greeter {
  String greet(String name) => 'Hello, $name!';
}

class HealthController extends Controller {
  // Without reflection, `@Expose` annotations cannot be read, so the mount
  // path is passed explicitly and routes are added in `configureRoutes`.
  HealthController() : super(expose: const Expose('/health'));

  @override
  void configureRoutes(Routable routable) {
    routable.get('/', (req, res) => {'status': 'ok'});
  }
}

void main() async {
  // Logging set up/boilerplate
  Logger.root.onRecord.listen(print);

  // No `reflector`: reflection is disabled.
  var app = Angel(logger: Logger('angel'));

  // Types to inject are registered in the container up front.
  app.container.registerSingleton(Greeter());

  // A RESTful service that manages an in-memory collection.
  app.use('/api/todos', MapService());

  // A controller that declares its routes explicitly.
  await app.configure(HealthController().configureServer);

  // Dependency injection with an explicit `InjectionRequest`,
  // instead of reflecting on the closure's parameters.
  app.get(
    '/greet/:name',
    ioc(
      (Greeter greeter, String name) => greeter.greet(name),
      injection: InjectionRequest.constant(
        required: [
          Greeter,
          ['name', String],
        ],
      ),
    ),
  );

  app.fallback((req, res) => throw AngelHttpException.notFound());

  var http = AngelHttp(app);
  var port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 0;
  await http.startServer('127.0.0.1', port);
  print('Listening at ${http.uri}');
}
