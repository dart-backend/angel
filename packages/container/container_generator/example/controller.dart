/// An `@Expose` controller without `dart:mirrors`, so the app can be
/// AOT-compiled (even obfuscated):
///
/// ```sh
/// dart run build_runner build
/// dart compile exe example/controller.dart -o server
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

part 'controller.g.dart';

@injectable
@Expose('/greet')
class GreetController extends Controller {
  // GET /greet/hello/:name
  String getHello(String name) => 'Hello, $name!';

  // GET /greet/shout?text=...
  @Expose('/shout')
  String shout(@Query('text') String text) => text.toUpperCase();
}

void main() async {
  var app = Angel(reflector: StaticReflector.combine([controllerReflection]));
  await app.configure(GreetController().configureServer);
  var http = AngelHttp(app);
  var server = await http.startServer('127.0.0.1', 0);

  var client = HttpClient();
  for (var path in ['/greet/hello/world', '/greet/shout?text=aot']) {
    var rs = await (await client.get('127.0.0.1', server.port, path)).close();
    print('$path -> ${rs.statusCode} ${await rs.transform(utf8.decoder).join()}');
  }
  client.close();
  await http.close();
}
