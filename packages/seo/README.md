# Angel3 SEO

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_seo?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/seo/LICENSE)

Helpers for building SEO-friendly Web pages in Angel. The goal of `package:angel3_seo` is to speed up perceived client page loads, prevent the infamous [flash of unstyled content](https://en.wikipedia.org/wiki/Flash_of_unstyled_content), and other SEO optimizations that can easily become tedious to perform by hand.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_seo: ^10.0.0
```

## Usage

### Disabling inlining per-element

Add a `data-no-inline` attribute to a `link` or `script` to prevent inlining it:

```html
<script src="main.dart.js" data-no-inline></script>
```

### `inlineAssets`

A [response finalizer](https://angel3-docs.dukefirehawk.com/guides/request-lifecycle) that can be used in any application to patch HTML responses, including those sent with a templating engine like Jael3.

In any `text/html` response sent down, `link` and `script` elements that point to internal resources will have the contents of said file read, and inlined into the HTML page itself.

In this case, "internal resources" refers to a URI *without* a scheme or host, i.e. `/site.css` or `foo/bar/baz.js`, of a file in the asset directory: a leading `/` is its root, and a path out of it (`../secret`) is never inlined.

The content of a file is inlined as text, so it cannot end its `<style>` or `<script>` early (`</script` is written `<\/script`). A stylesheet keeps its `media`. A script that is `async`, or `defer` but not a module, stays external, as an inline script runs at once. An element marked `data-no-inline`, or without a valid `href` or `src`, is left as it is. The page is sent as UTF-8.

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_seo/angel3_seo.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/local.dart';

void main() async {
  var app = Angel();
  var fs = const LocalFileSystem();
  var http = AngelHttp(app);

  app.responseFinalizers.add(inlineAssets(fs.directory('web')));

  app.fallback((req, res) => throw AngelHttpException.notFound());

  var server = await http.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
```

### `inlineAssetsFromVirtualDirectory`

This function wraps a `VirtualDirectory` to patch the way it sends `.html` and `.htm` files. Produces the same functionality as `inlineAssets`. The inlined page is then served by the wrapped directory, so the caching of a `CachingVirtualDirectory`, `Range` requests and its `callback` apply to it; its `Last-Modified` and ETag are of the latest of the page and its assets.

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_seo/angel3_seo.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/local.dart';

void main() async {
  var app = Angel();
  var fs = const LocalFileSystem();
  var http = AngelHttp(app);

  var vDir = inlineAssetsFromVirtualDirectory(
    CachingVirtualDirectory(
      app,
      fs,
      source: fs.directory('web'),
    ),
  );

  app.fallback(vDir.handleRequest);

  app.fallback((req, res) => throw AngelHttpException.notFound());

  var server = await http.startServer('127.0.0.1', 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}
```
