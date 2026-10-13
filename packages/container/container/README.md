# Angel3 Container

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_container?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/container/container/LICENSE)

A better IoC container for Angel3, ultimately allowing Angel3 to be used with or without `dart:mirrors` package.

This package does not use `dart:mirrors`. Pick a `Reflector` backend:

* `MirrorsReflector`, from [`angel3_container_mirrors`](https://pub.dev/packages/angel3_container_mirrors), for apps run on the Dart VM
* `StaticReflector.combine([...])`, from this package, with the data that [`angel3_container_generator`](https://pub.dev/packages/angel3_container_generator) generates for `@injectable` classes, for apps compiled ahead of time
* `EmptyReflector` or `ThrowingReflector`, from this package, when everything is registered explicitly

Before 10.0.0, `MirrorsReflector` was imported from `package:angel3_container/mirrors.dart`. Add `angel3_container_mirrors` to your dependencies and import `package:angel3_container_mirrors/angel3_container_mirrors.dart` instead.

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
