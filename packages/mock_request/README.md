# Mock HTTP Request

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_mock_request?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/mock_request/LICENSE)

**Forked from `mock_request` to support NNBD**

Manufacture dart:io HttpRequests, HttpResponses, HttpHeaders, etc. This makes it possible to test server-side Dart applications without having to ever bind to a port.

This package was originally designed to make testing [Angel3](https://angel3-framework.web.app/) applications smoother, but works with any Dart-based server.

## Installation

In your `pubspec.yaml`:

```yaml
dev_dependencies:
  angel3_mock_request: ^10.0.0
```

## Usage

```dart
var rq = MockHttpRequest('GET', Uri.parse('/foo'));
await rq.close();
await AngelHttp(app).handleRequest(rq); // Run within your server-side application
var rs = rq.response;
expect(rs.statusCode, equals(200));
expect(await rs.transform(utf8.decoder).join(),
    equals(json.encode('Hello, world!')));
```

More examples can be found in the included test cases.

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **Streams**: `MockHttpRequest` extends `Stream<Uint8List>`, so its stream methods have the signatures of `dart:io`'s `HttpRequest`; code that treated it as a `Stream<List<int>>` may need `.cast<List<int>>()`.
* **Encoding**: `write` throws an `ArgumentError` for a character its encoding cannot represent, instead of truncating it. Set the `content-type` charset, or `encoding`, to one that can represent it.
