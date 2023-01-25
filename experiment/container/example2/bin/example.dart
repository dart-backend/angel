import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_container_generator/angel3_container_generator.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

import 'example.reflectable.dart';

@Expose('/controller')
class MyController extends Controller {
  @Expose('/')
  a() => "Hello, world!";
}

void main() async {
  var reflector = const GeneratedReflector();
  Container container = Container(reflector);

  container.registerSingleton<MyController>(MyController());

  initializeReflectable();

  var app = Angel(reflector: reflector);

  var http = AngelHttp(app);

  await app.mountController<MyController>();

  var server = await http.startServer();
  print("Angel server listening at ${http.uri}");
}
