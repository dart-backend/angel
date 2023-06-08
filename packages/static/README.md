# Angel3 Static Files Handler

[![version](https://img.shields.io/badge/pub-v4.1.0-brightgreen)](https://pub.dev/packages/angel3_static)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/belatuk-common-utilities)](https://github.com/dukefirehawk/angel/tree/angel3/packages/static/LICENSE)

This library provides a virtual directory to serve static files such as html, css and js for [Angel3 framework](https://pub.dev/packages/angel3). It can also handle `Range` requests, making it suitable for media streaming, i.e. music, video, etc.*

## Installation

In `pubspec.yaml`:

```yaml
dependencies:
    angel3_static: ^8.0.0
```

## Usage

To serve files from a directory, you need to create a `VirtualDirectory`. Keep in mind that `angel3_static` uses `package:file` instead of `dart:io`.

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_static/angel3_static.dart';
import 'package:file/local.dart';

void main() async {
  var app = Angel();
  var fs = const LocalFileSystem();

  // Normal static server
  var vDir = VirtualDirectory(app, fs, source: Directory('./public'));

  // Send Cache-Control, ETag, etc. as well
  var vDir = CachingVirtualDirectory(app, fs, source: Directory('./public'));

  // Mount the VirtualDirectory's request handler
  app.fallback(vDir.handleRequest);

  // Start your server!!!
  await AngelHttp(app).startServer();
}
```

## Push State

`VirtualDirectory` also exposes a `pushState` method that returns a request handler that serves the file at a given path as a fallback, unless the user is requesting that file. This can be very useful for SPA's.

```dart
// Create VirtualDirectory as well
var vDir = CachingVirtualDirectory(...);

// Mount it
app.fallback(vDir.handleRequest);

// Fallback to index.html on 404
app.fallback(vDir.pushState('index.html'));
```

## Options

The `VirtualDirectory` API accepts a few named parameters:

- **source**: A `Directory` containing the files to be served. If left null, then Angel3 will serve either from `web` (in development) or
    `build/web` (in production), depending on your `ANGEL_ENV`.
- **indexFileNames**: A `List<String>` of filenames that should be served as index pages. Default is `['index.html']`.
- **publicPath**: To serve index files, you need to specify the virtual path under which
    angel3_static is serving your files. If you are not serving static files at the site root,
    please include this.
- **callback**: Runs before sending a file to a client. Use this to set headers, etc. If it returns anything other than `null` or `true`, then the callback's result will be sent to the user, instead of the file contents.
