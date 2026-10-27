# Angel3 Container

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_container?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/container/container/LICENSE)

A better IoC container for Angel3, ultimately allowing Angel3 to be used with or without `dart:mirrors` package.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_container: ^10.0.0
```

## Usage

Register what to inject, then `make` it:

```dart
import 'package:angel3_container/angel3_container.dart';

void main() async {
  // Everything here is registered, so it needs no reflection.
  var container = Container(const EmptyReflector());

  // Register a singleton.
  container.registerSingleton<Engine>(Engine(40));

  // Register a factory that creates a truck.
  container.registerFactory<Truck>((container) {
    return Truck(container.make<Engine>());
  });

  // Use `make` to create an instance.
  container.make<Truck>().drive(); // Vroom! I have 40 horsepower.

  // You can also resolve injections asynchronously.
  container.registerFactory<Future<int>>((_) async => 24);
  print(await container.makeAsync<int>()); // 24

  // A child container can override a factory of its parent.
  var child = container.createChild()
    ..registerFactory<Truck>((_) => Truck(Engine(5666)));
  child.make<Truck>().drive(); // Vroom! I have 5666 horsepower.
}

class Engine {
  final int horsePower;

  Engine(this.horsePower);
}

class Truck {
  final Engine engine;

  Truck(this.engine);

  void drive() => print('Vroom! I have ${engine.horsePower} horsepower.');
}
```

### Reflectors

This package does not use `dart:mirrors`. Pick a `Reflector` backend:

* `MirrorsReflector`, from [`angel3_container_mirrors`](https://pub.dev/packages/angel3_container_mirrors), for apps run on the Dart VM
* `StaticReflector.combine([...])`, from this package, with the data that [`angel3_container_generator`](https://pub.dev/packages/angel3_container_generator) generates for `@injectable` classes, for apps compiled ahead of time
* `EmptyReflector` or `ThrowingReflector`, from this package, when everything is registered explicitly

Before 10.0.0, `MirrorsReflector` was imported from `package:angel3_container/mirrors.dart`. Add `angel3_container_mirrors` to your dependencies and import `package:angel3_container_mirrors/angel3_container_mirrors.dart` instead.

### With Angel3

With a reflector, the app constructs controllers and injects their dependencies:

```dart
    import 'package:angel3_container_mirrors/angel3_container_mirrors.dart';
    import 'package:angel3_framework/angel3_framework.dart';
    import 'package:angel3_framework/http.dart';

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

        // Sales Controller
        app.container.registerSingleton<SalesController>(SalesController());
        await app.mountController<SalesController>();

        var http = AngelHttp(app);
        var server = await http.startServer('localhost', 3000);
        print("Angel3 server listening at ${http.uri}");
    }
```

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **`MirrorsReflector`**: `package:angel3_container/mirrors.dart` is removed. Add [`angel3_container_mirrors`](https://pub.dev/packages/angel3_container_mirrors) to your dependencies, and import `package:angel3_container_mirrors/angel3_container_mirrors.dart` instead.
* **Optional parameters**: `Container.make` leaves out an optional positional parameter whose type is not registered, so it is `null` or keeps its default, instead of constructing it by reflection. Register the types you want injected.
* **`StaticReflectedInstance.getField`** throws a `ReflectionException` for a name that is no member, instead of returning `null`, and a `StaticMemberReader` returns `noStaticMember` for it.
