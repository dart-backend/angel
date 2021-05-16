# angel3_jael
[![version](https://img.shields.io/badge/pub-v4.0.1-brightgreen)](https://pub.dartlang.org/packages/angel3_jael)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/jael/angel_jael/LICENSE)



[Angel](https://github.com/dukefirehawk/angel/tree/angel3)
support for
[Jael](https://github.com/dukefirehawk/angel/tree/angel3/packages/jael/jael).

# Installation
In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_jael: ^4.0.0
```

# Usage
Just like `mustache` and other renderers, configuring Angel to use
Jael is as simple as calling `app.configure`:

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

`package:angel3_jael` supports caching views, to improve server performance.
You might not want to enable this in development, so consider setting
the flag to `app.isProduction`:

```
jael(viewsDirectory, cacheViews: app.isProduction);
```

Keep in mind that this package uses `package:file`, rather than
`dart:io`.

The following is a basic example of a server setup that can render Jael
templates from a directory named `views`:

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_jael/angel3_jael.dart';
import 'package:file/local.dart';
import 'package:logging/logging.dart';

main() async {
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

To apply additional transforms to parsed documents, provide a
set of `patch` functions, like in `package:jael3_preprocessor`.