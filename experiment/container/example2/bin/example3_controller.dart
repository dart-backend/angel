import 'package:angel3_container_generator/angel3_container_generator.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

import 'example3_controller.reflectable.dart';

@contained
@Expose('/controller', method: 'GET')
class MyController extends Controller {
  @Expose('/')
  Order order(Order singleton) => singleton;

  //Todo todo(Todo singleton) => singleton;
}

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

class FoodItem {
  final String name;
  final num price;
  final num qty;

  FoodItem(this.name, this.price, this.qty);
}

class Order {
  FoodItem item;

  String? get name => item.name;

  Order(this.item);
}

void main() async {
  //var reflector = const GeneratedReflector();
  //Container container = Container(reflector);
  //container.registerSingleton<SalesController>(SalesController());

  // Using GeneratedReflector
  initializeReflectable();
  var app = Angel(reflector: GeneratedReflector());

  // Using MirrorReflector
  //var app = Angel(reflector: MirrorsReflector());
  //await app.configure(MyController().configureServer);

  // My Controller
  //app.container.registerSingleton<MyController>(MyController());
  //await app.mountController<MyController>();
  await app.configure(MyController().configureServer);

  // Sales Controller
  //app.container.registerSingleton<SalesController>(SalesController());
  //await app.mountController<SalesController>();

  var http = AngelHttp(app);

  var server = await http.startServer('localhost', 3000);
  print("Angel server listening at ${http.uri}");
}
