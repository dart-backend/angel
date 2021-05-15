# angel3_test
[![version](https://img.shields.io/badge/pub-v4.0.1-brightgreen)](https://pub.dartlang.org/packages/angel3_tet)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/test/LICENSE)

Testing utility library for the Angel framework.

# TestClient
The `TestClient` class is a custom `angel3_client` that sends mock requests to your server.
This means that you will not have to bind your server to HTTP to run.
Plus, it is an `angel3_client`, and thus supports services and other goodies.

The `TestClient` also supports WebSockets. WebSockets cannot be mocked (yet!) within this library,
so calling the `websocket()` function will also bind your server to HTTP, if it is not already listening.

The return value is a `WebSockets` client instance
(from [`package:angel3_websocket`](https://github.com/dukefirehawk/angel/tree/angel3/packages/websocket));

```dart
var ws = await client.websocket('/ws');
ws.service('api/users').onCreated.listen(...);

// To receive all blobs of data sent on the WebSocket:
ws.onData.listen(...);
```

# Matchers
Several `Matcher`s are bundled with this package, and run on any `package:http` `Response`,
not just those returned by Angel.

```dart
test('foo', () async {
    var res = await client.get('/foo');
    expect(res, allOf([
        isJson({'foo': 'bar'}),
        hasStatus(200),
        hasContentType(ContentType.JSON),
        hasContentType('application/json'),
        hasHeader('server'), // Assert header present
        hasHeader('server', 'angel'), // Assert header present with value
        hasHeader('foo', ['bar', 'baz']), // ... Or multiple values
        hasBody(), // Assert non-empty body
        hasBody('{"foo":"bar"}') // Assert specific body
    ]));
});

test('error', () async {
    var res = await client.get('/error');
    expect(res, isAngelHttpException());
    expect(res, isAngelHttpException(statusCode: 404, message: ..., errors: [...])) // Optional
});
```

`hasValidBody` is one of the most powerful `Matcher`s in this library,
because it allows you to validate a JSON body against a
[validation schema](https://github.com/dukefirehawk/angel/tree/angel3/packages/validate).

Angel provides a comprehensive validation library that integrates tightly
with the very `matcher` package that you already use for testing.

[`package:angel3_validate`](https://github.com/dukefirehawk/angel/tree/angel3/packages//validate)

```dart
test('validate response', () async {
    var res = await client.get('/bar');
    expect(res, hasValidBody(new Validator({
        'foo': isBoolean,
        'bar': [isString, equals('baz')],
        'age*': [],
        'nested': someNestedValidator
    })));
});
```