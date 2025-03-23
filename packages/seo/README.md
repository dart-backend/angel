# Angel3 SEO

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_seo?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/seo/LICENSE)

Helpers for building SEO-friendly Web pages in Angel. The goal of `package:angel3_seo` is to speed up perceived client page loads, prevent the infamous [flash of unstyled content](https://en.wikipedia.org/wiki/Flash_of_unstyled_content), and other SEO optimizations that can easily become tedious to perform by hand.

## Disabling inlining per-element

Add a `data-no-inline` attribute to a `link` or `script` to prevent inlining it:

```html
<script src="main.dart.js" data-no-inline></script>
```

## `inlineAssets`

A [response finalizer](https://angel3-docs.dukefirehawk.com/guides/request-lifecycle) that can be used in any application to patch HTML responses, including those sent with a templating engine like Jael3.

In any `text/html` response sent down, `link` and `script` elements that point to internal resources will have the contents of said file read, and inlined into the HTML page itself.

In this case, "internal resources" refers to a URI *without* a scheme, i.e. `/site.css` or `foo/bar/baz.js`.

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_seo/angel3_seo.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/local.dart';

void main() async {
  var app = Angel()..lazyParseBodies = true;
  var fs = const LocalFileSystem();
  var http = AngelHttp(app);

  app.responseFinalizers.add(inlineAssets(fs.directory('web')));

  app.use(() => throw AngelHttpException.notFound());

  var server = await http.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
```

## `inlineAssetsFromVirtualDirectory`

This function is a simple one; it wraps a `VirtualDirectory` to patch the way it sends `.html` files. Produces the same functionality as `inlineAssets`.

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_seo/angel3_seo.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/local.dart';

void main() async {
  var app = Angel()..lazyParseBodies = true;
  var fs = const LocalFileSystem();
  var http = AngelHttp(app);

  var vDir = inlineAssets(
    VirtualDirectory(
      app,
      fs,
      source: fs.directory('web'),
    ),
  );

  app.use(vDir.handleRequest);

  app.use(() => throw AngelHttpException.notFound());

  var server = await http.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
```
