# Angel3 Anthentication

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_auth?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/auth/LICENSE)

A complete authentication plugin for Angel3. Inspired by Passport. More details in the [User Guide](https://angel3-docs.dukefirehawk.com/guides/authentication).

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_auth: ^10.0.0
```

## Bundled Strategies

* Local (with and without Basic Auth)
* Find other strategies (Twitter, Google, OAuth2, etc.) on pub

## Usage

Ensure you have read the [User Guide](https://angel3-docs.dukefirehawk.com/guides/authentication).

```dart
import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';

void main() async {
  var app = Angel();
  var auth = AngelAuth<User>(
    serializer: (user) => user.id ?? '',
    deserializer: (id) => fetchAUserByIdSomehow(id),
  );

  // Middleware to decode JWT's and inject a user object...
  await app.configure(auth.configureServer);

  auth.strategies['local'] = LocalAuthStrategy((username, password) {
    // Retrieve a user somehow...
    // If authentication succeeds, return a User object.
    //
    // Otherwise, return `null`.
    return null;
  });

  app.post('/auth/local', auth.authenticate('local'));

  // Each strategy of a list is tried in turn. If one succeeds, the rest are
  // skipped; if the last one fails, a `401 Not Authenticated` is thrown.
  app.post('/auth/any', auth.authenticate(['local', 'basic']));

  var http = AngelHttp(app);
  await http.startServer('127.0.0.1', 3000);
}

class User {
  String? id, username, password;
}

Future<User> fetchAUserByIdSomehow(String id) async {
  // Fetch a user somehow...
  throw UnimplementedError();
}
```

## Security defaults

* A JWT expires after a day (`jwtLifeSpan`, in milliseconds; `-1` for never, which is warned about with a fixed `jwtKey`).
* `POST /auth/token` exchanges a JWT that is still valid for a new one; an expired one only within `reviveGracePeriod` (default: none). The user must still exist.
* The `token` cookie is `HttpOnly`, `Secure` and `SameSite=Lax` (`cookieSameSite`), and is set when a user logs in, not for requests authenticated with an `Authorization: Bearer` header. `logout` expires it.
* A JWT in the query string (`?token=`) is ignored unless `allowTokenInQuery` is `true`, as query strings end up in logs, history and `Referer` headers.

## Default Authentication Callback

A frequent use case within SPA's is opening OAuth login endpoints in a separate window. [`angel3_client`](https://pub.dev/packages/angel3_client) provides a facility for this, which works perfectly with the default callback provided in this package.

```dart
configureServer(Angel app) async {
  var handler = auth.authenticate(
    'facebook',
    AngelAuthOptions(callback: confirmPopupAuthentication()));
  app.get('/auth/facebook', handler);
  
  // Use a comma to try multiple strategies!!!
  //
  // Each strategy is run sequentially. If one succeeds, the loop ends.
  // Authentication failures will just cause the loop to continue.
  // 
  // If the last strategy throws an authentication failure, then
  // a `401 Not Authenticated` is thrown.
  var chainedHandler = auth.authenticate(
    ['basic','facebook'],
    authOptions
  );
}
```

This renders a simple HTML page that fires the user's JWT as a `token` event in `window.opener`. `angel3_client` [exposes this as a Stream](https://pub.dev/documentation/angel3_client/latest/):

```dart
app.authenticateViaPopup('/auth/google').listen((jwt) {
  // Do something with the JWT
});
```

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **JWT lifetime**: a JWT expires after a day by default (`AngelAuth.defaultJwtLifeSpan`). Pass `jwtLifeSpan` (in milliseconds) for another lifetime; `-1`, which never expires, is warned about with a fixed `jwtKey`.
* **Reviving JWTs**: `POST /auth/token` renews a JWT that is still valid, and an expired one only within `reviveGracePeriod` (default: none), if its user still exists. Clients that revived expired JWTs must log in again, or give a grace period:

  ```dart
  var auth = AngelAuth<User>(
    serializer: (user) => user.id ?? '',
    deserializer: (id) => fetchAUserByIdSomehow(id),
    reviveGracePeriod: const Duration(days: 7),
  );
  ```

* **Cookie**: the `token` cookie is `SameSite=Lax` (`cookieSameSite`), and is set only when a user logs in or a JWT is revived, not for requests with an `Authorization: Bearer` header.
* **Token in the query string**: `?token=` is ignored unless `allowTokenInQuery` is `true`. Enable it for the browser WebSocket client of `angel3_websocket`, which cannot send headers.
* **Claims**: JWTs have the standard `iat` and `exp` claims, in seconds. JWTs issued by 9.x are still read.
