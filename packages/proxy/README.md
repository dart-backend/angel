# Angel3 Proxy

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_proxy?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/proxy/LICENSE)

Angel3 middleware to forward requests to another server (i.e. `webdev serve`). Also supports WebSockets.

```dart
import 'package:angel3_proxy/angel3_proxy.dart';
import 'package:http/http.dart' as http;

void main() async {
  // Forward requests instead of serving statically.
  // You can also pass a URI, instead of a string.
  var proxy1 = Proxy('http://localhost:3000');
  
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
