/// Constructor injection without `dart:mirrors`, so this program can be
/// AOT-compiled:
///
/// ```sh
/// dart run build_runner build
/// dart compile exe example/main.dart -o greeter
/// ```
library;

import 'package:angel3_container/angel3_container.dart';

part 'main.g.dart';

@injectable
class Config {
  final String greeting;

  Config([this.greeting = 'Hello']);
}

@injectable
class Greeter {
  final Config config;
  final String punctuation;

  Greeter(this.config, {this.punctuation = '!'});

  String greet(String name) => '${config.greeting}, $name$punctuation';
}

void main() {
  var container = Container(StaticReflector.combine([mainReflection]));
  print(container.make<Greeter>().greet('world'));

  container
    ..registerSingleton(Config('Hi'))
    ..registerSingleton<String>('?');
  print(container.make<Greeter>().greet('AOT'));
}
