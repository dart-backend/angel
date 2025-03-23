# Angel3 Test

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_test?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/test/LICENSE)

Testing utility library for Angel3 framework.

## TestClient

The `TestClient` class is a custom `angel3_client` that sends mock requests to your server. This means that you will not have to bind your server to HTTP to run. Plus, it is an `angel3_client`, and thus supports services and other goodies. The `TestClient` also supports WebSockets. WebSockets cannot be mocked (yet!) within this library, so calling the `websocket()` function will also bind your server to HTTP, if it is not already listening. The return value is a `WebSockets` client instance (from [`package:angel3_websocket`](<https://pub.dev/packages/angel3_websocket>));

```dart
var ws = await client.websocket('/ws');
ws.service('api/users').onCreated.listen(...);

// To receive all blobs of data sent on the WebSocket:
ws.onData.listen(...);
```

## Matchers

Several `Matcher`s are bundled with this package, and run on any `package:http` `Response`, not just those returned by Angel.

```dart
void test('foo', () async {
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

void test('error', () async {
    var res = await client.get('/error');
    expect(res, isAngelHttpException());
    expect(res, isAngelHttpException(statusCode: 404, message: ..., errors: [...])) // Optional
});
```

`hasValidBody` is one of the most powerful `Matcher`s in this library, because it allows you to validate a JSON body against a validation schema. Angel3 provides a comprehensive [validation library](<https://pub.dev/packages/angel3_validate>) that integrates tightly with the `matcher` package that you already use for testing.

```dart
test('validate response', () async {
    var res = await client.get('/bar');
    expect(res, hasValidBody(Validator({
        'foo': isBoolean,
        'bar': [isString, equals('baz')],
        'age*': [],
        'nested': someNestedValidator
    })));
});
```
