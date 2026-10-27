import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_container_mirrors/angel3_container_mirrors.dart';

void main() {
  var container = Container(const MirrorsReflector())
    ..registerSingleton<Engine>(Engine(40));

  // Truck is not registered: MirrorsReflector finds its constructor, and the
  // container injects the Engine singleton.
  container.make<Truck>().drive();
}

class Engine {
  final int horsePower;

  Engine(this.horsePower);
}

class Truck {
  final Engine engine;

  Truck(this.engine);

  void drive() {
    print('Vroom! I have ${engine.horsePower} horsepower in my engine.');
  }
}
