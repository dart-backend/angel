# Angel3 Test

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_test?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/test/LICENSE)

Testing utility library for Angel3 framework.

## Installation

In your `pubspec.yaml`:

```yaml
dev_dependencies:
  angel3_test: ^10.0.0
```

## Usage

Connect a `TestClient` to your app with `connectTo`, and send requests to it, without binding to a port:

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;

  setUp(() async {
    var app = Angel()..get('/hello', (req, res) => {'hello': 'world'});
    client = await connectTo(app);
  });

  tearDown(() => client.close());

  test('hello', () async {
    var res = await client.get(Uri.parse('/hello'));
    expect(res, allOf(hasStatus(200), isJson({'hello': 'world'})));
  });
}
```

### TestClient

The `TestClient` class is a custom `angel3_client` that sends mock requests to your server. This means that you will not have to bind your server to HTTP to run. Plus, it is an `angel3_client`, and thus supports services and other goodies. The `TestClient` also supports WebSockets. WebSockets cannot be mocked (yet!) within this library, so calling the `websocket()` function will also bind your server to HTTP, if it is not already listening. The return value is a `WebSockets` client instance (from [`package:angel3_websocket`](<https://pub.dev/packages/angel3_websocket>));

```dart
var ws = await client.websocket('/ws');
ws.service('api/users').onCreated.listen(...);

// To receive all blobs of data sent on the WebSocket:
ws.onData.listen(...);
```

### Matchers

Several `Matcher`s are bundled with this package, and run on any `package:http` `Response`, not just those returned by Angel.

```dart
test('foo', () async {
    var res = await client.get(Uri.parse('/foo'));
    expect(res, allOf([
        isJson({'foo': 'bar'}),
        hasStatus(200),
        hasContentType(ContentType.json),
        hasContentType('application/json'),
        hasHeader('server'), // Assert header present
        hasHeader('server', 'angel'), // Assert header present with value
        hasHeader('foo', ['bar', 'baz']), // ... Or multiple values
        hasBody(), // Assert non-empty body
        hasBody('{"foo":"bar"}') // Assert specific body
    ]));
});

test('error', () async {
    var res = await client.get(Uri.parse('/error'));
    expect(res, isAngelHttpException());
    expect(res, isAngelHttpException(statusCode: 404, message: ..., errors: [...])); // Optional
});
```

`hasValidBody` is one of the most powerful `Matcher`s in this library, because it allows you to validate a JSON body against a validation schema. Angel3 provides a comprehensive [validation library](<https://pub.dev/packages/angel3_validate>) that integrates tightly with the `matcher` package that you already use for testing.

```dart
test('validate response', () async {
    var res = await client.get(Uri.parse('/bar'));
    expect(res, hasValidBody(Validator({
        'foo': isBoolean,
        'bar': [isString, equals('baz')],
        'age*': [],
        'nested': someNestedValidator
    })));
});
```

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **`contentLength`**: a `TestClient` response reports the `contentLength` the handler set, or `null` when none was set or the body was decompressed, instead of `0`.
* **`TestClient.service()`** no longer takes `type`. Pass a `deserializer` instead:

  ```dart
  var todos = client.service<String, Todo>(
    'api/todos',
    deserializer: (x) => TodoSerializer.fromMap(x as Map),
  );
  ```
