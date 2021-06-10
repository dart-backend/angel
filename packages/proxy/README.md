# angel3_proxy
[![version](https://img.shields.io/badge/pub-v4.0.0-brightgreen)](https://pub.dartlang.org/packages/angel3_proxy)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/proxy/LICENSE)

Angel middleware to forward requests to another server (i.e. `webdev serve`).
Also supports WebSockets.

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

Request bodies will be forwarded as well, if they are not empty. This allows things like POST requests to function.

For a request body to be forwarded, the body must not have already been parsed.