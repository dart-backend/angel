import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:logging/logging.dart';

void main() async {
  print("Starting up");
  //Logger.root.onRecord.listen(print);

  var app = Angel(logger: Logger('example'), reflector: MirrorsReflector());
  var http = AngelHttp(app);

  app.get("/", (req, res) => "Hello, world!");

  // Simple fallback to throw a 404 on unknown paths.
  /*
  app.fallback((req, res) {
    throw AngelHttpException.notFound(
      message: 'Unknown path: "${req.uri?.path}"',
    );
  });
  */

  await http.startServer('localhost', 3000);

  print("End");
}
