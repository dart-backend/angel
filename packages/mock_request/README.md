# angel3_mock_request
[![version](https://img.shields.io/badge/pub-v2.12.4-brightgreen)](https://pub.dartlang.org/packages/angel3_mock_request)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/mock_request/LICENSE)

Manufacture dart:io HttpRequests, HttpResponses, HttpHeaders, etc.
This makes it possible to test server-side Dart applications without
having to ever bind to a port.

This package was originally designed to testing
[Angel](https://github.com/dukefirehawk/angel/tree/angel3)
applications smoother, but works with any Dart-based server. :)

# Usage
```dart
var rq = MockHttpRequest('GET', Uri.parse('/foo'));
await rq.close();
await app.handleRequest(rq); // Run within your server-side application
var rs = rq.response;
expect(rs.statusCode, equals(200));
expect(await rs.transform(UTF8.decoder).join(),
    equals(JSON.encode('Hello, world!')));
```

More examples can be found in the included tests.