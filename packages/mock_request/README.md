# Mock HTTP Request

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_mock_request?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/mock_request/LICENSE)

**Forked from `mock_request` to support NNBD**

Manufacture dart:io HttpRequests, HttpResponses, HttpHeaders, etc. This makes it possible to test server-side Dart applications without
having to ever bind to a port.

This package was originally designed to make testing [Angel3](https://angel3-framework.web.app/) applications smoother, but works with any Dart-based server.

## Usage

```dart
var rq = MockHttpRequest('GET', Uri.parse('/foo'));
await rq.close();
await app.handleRequest(rq); // Run within your server-side application
var rs = rq.response;
expect(rs.statusCode, equals(200));
expect(await rs.transform(UTF8.decoder).join(),
    equals(JSON.encode('Hello, world!')));
```

More examples can be found in the included test cases.
