# Angel3 Jael

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_jael?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/jael/angel_jael/LICENSE)

[Angel 3](https://pub.dev/packages/angel3_framework) support for [Jael 3](https://pub.dev/packages/jael3).

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_jael: ^6.0.0
```

## Usage

Just like `mustache` and other renderers, configuring Angel to use Jael is as simple as calling `app.configure`:

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_jael/angel3_jael.dart';
import 'package:file/file.dart';

AngelConfigurer myPlugin(FileSystem fileSystem) {
    return (Angel app) async {
        // Connect Jael to your server...
        await app.configure(
        jael(fileSystem.directory('views')),
      );
    };
}
```

`package:angel3_jael` supports caching views and minified html output by default, to improve performance. You might want to disable them in development, so consider setting these flags to `false`:

```dart
jael(viewsDirectory, cacheViews: false, minified: false);
```

Keep in mind that this package uses `package:file`, rather than `dart:io`.

The following is a basic example of a server setup that can render Jael templates from a directory named `views`:

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_jael/angel3_jael.dart';
import 'package:file/local.dart';
import 'package:logging/logging.dart';

void main() async {
  var app = Angel();
  var fileSystem = const LocalFileSystem();

  await app.configure(
    jael(fileSystem.directory('views')),
  );

  // Render the contents of views/index.jael
  app.get('/', (res) => res.render('index', {'title': 'ESKETTIT'}));

  app.use(() => throw AngelHttpException.notFound());

  app.logger = Logger('angel')
    ..onRecord.listen((rec) {
      print(rec);
      if (rec.error != null) print(rec.error);
      if (rec.stackTrace != null) print(rec.stackTrace);
    });

  var server = await app.startServer(null, 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
```

To apply additional transforms to parsed documents, provide a set of `patch` functions, like in `package:jael3_preprocessor`.

## Performance Optimization

For handling large volume of initial requests, consider using `jaelTemplatePreload` to preload all the JAEL templates
into an external cache.

```dart

  var templateDir = fileSystem.directory('views');

  // Preload JAEL view templates into cache
  var viewCache = <String, Document>{};
  jaelTemplatePreload(templateDir, viewCache);

  // Inject cache into JAEL renderer
  await app.configure(
    jael(fileSystem.directory('views'), cache: viewCache),
  );

```
