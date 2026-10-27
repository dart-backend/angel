# Angel3 CORS middleware

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_cors?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/cors/LICENSE)

CORS headers middleware for Angel3. Ported from [Express CORS middleware](https://github.com/expressjs/cors) to Angel3 framework.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_cors: ^10.0.0
```

## Usage

```dart
import 'package:angel3_cors/angel3_cors.dart';
import 'package:angel3_framework/angel3_framework.dart';

Future configureServer(Angel app) async {
  // The default options allow CORS from any origin, without credentials.
  // Combined with `fallback`, you can enable CORS application-wide.
  app.fallback(cors());

  // You can also enable CORS for a single route.
  app.get('/my_api', chain([cors(), (req, res) => 'Hello']));

  // Of course, you can configure CORS.
  app.chain([
    cors(
      CorsOptions(
        origin: ['https://example.org', RegExp(r'^https://[a-z]+\.example\.org$')],
        allowedHeaders: ['Content-Type', 'Authorization'],
      ),
    ),
  ]).group('/api', (router) {
    router.get('/version', (req, res) => 'v0');
  });
}
```

See the [example file](example/example.dart) for all the options.

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **`origin: false`** disables CORS, as documented, where it allowed every origin with `Access-Control-Allow-Origin: *`.
* **Refused origins**: a refused origin, or a request without one, gets no `Access-Control-Allow-Origin` header, where it got `false`; its preflight is still answered.
* **Preflights only**: `cors` answers only preflight requests (`OPTIONS` with an `Access-Control-Request-Method` header). Another `OPTIONS` request, or one made `OPTIONS` by a method override, goes on to the app's handlers, where `cors` answered it with `successStatus`.
* **`Access-Control-Allow-Headers`** is sent on preflights only.
* **`origin`** must be one of the types `CorsOptions` describes (a `String`, `RegExp`, `bool`, `List` or predicate); another is an `ArgumentError` of the constructor, where it allowed every origin.
