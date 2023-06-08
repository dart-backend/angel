import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

class Todo extends Model {
  String? text;
  String? over;

  Todo({this.text, this.over});

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'over': over,
    };
  }
}

@Expose('/todo', method: 'GET')
class TodoController extends Controller {
  @Expose('/')
  Todo todo(Todo singleton) => singleton;
}

@Expose('/controller', method: 'GET')
class MyController extends Controller {
  @Expose('/', method: 'GET')
  Future<String> route1(RequestContext req, ResponseContext res) async {
    return "My route";
  }

  //Todo todo(Todo singleton) => singleton;
}

@Expose('/sales', middleware: [process1])
class SalesController extends Controller {
  @Expose('/', middleware: [process2])
  Future<String> route1(RequestContext req, ResponseContext res) async {
    return "Sales route";
  }
}

bool process1(RequestContext req, ResponseContext res) {
  res.write('Hello, ');
  return true;
}

bool process2(RequestContext req, ResponseContext res) {
  res.write('From Sales, ');
  return true;
}

void main() async {
  // Using Mirror Reflector
  var app = Angel(reflector: MirrorsReflector());

  await app.configure(MyController().configureServer);
  await app.configure(SalesController().configureServer);

  var http = AngelHttp(app);
  var server = await http.startServer('localhost', 3000);
  print("Angel server listening at ${http.uri}");
}
