# Angel3 Container

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_container?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/container/angel_container/LICENSE)

A better IoC container for Angel3, ultimately allowing Angel3 to be used with or without `dart:mirrors` package.

```dart
    import 'package:angel3_container/mirrors.dart';
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
        print("Angel server listening at ${http.uri}");
    }
```
