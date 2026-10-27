# Angel3 Proxy

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_proxy?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/proxy/LICENSE)

Angel3 middleware to forward requests to another server (i.e. `webdev serve`). Also supports WebSockets.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_proxy: ^10.0.0
```

## Usage

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_proxy/angel3_proxy.dart';

void main() async {
  var app = Angel();

  // Forward requests instead of serving statically.
  // You can also pass a URI, instead of a string.
  var proxy = Proxy('http://localhost:3000');

  // handle all methods (GET, POST, ...)
  app.fallback(proxy.handleRequest);
}
```

You can also restrict the proxy to serving only from a specific root:

```dart
Proxy(baseUrl, publicPath: '/remote');
```

Also, you can map requests to a root path on the remote server:

```dart
Proxy(baseUrl.replace(path: '/path'));
```

Request bodies will be forwarded as well, if they are not empty. This allows things like POST requests to function. For a request body to be forwarded, the body must not have already been parsed.
