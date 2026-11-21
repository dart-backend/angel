# Angel3 Authentication

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_auth?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/security/auth/LICENSE)

Authentication for Angel3, inspired by Passport. You register strategies, such as a username and password, and `AngelAuth` signs the user in with them. It issues a JWT, and gives every later request that carries the JWT its user. The [User Guide](https://angel3-docs.dukefirehawk.com/guides/authentication) has more details.

- [Installation](#installation)
- [Strategies](#strategies)
- [Usage](#usage)
  - [Trying several strategies](#trying-several-strategies)
  - [What a login answers](#what-a-login-answers)
  - [Protecting routes](#protecting-routes)
  - [Logging out](#logging-out)
- [Security defaults](#security-defaults)
- [Popup authentication](#popup-authentication)
- [Migrating from 9.x to 10.0.0](#migrating-from-9x-to-1000)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_auth: ^10.0.0
```

## Strategies

- **Bundled.** `LocalAuthStrategy` checks a username and password, from the form or, with `allowBasic`, from an `Authorization: Basic` header.
- **Others.** Strategies such as OAuth2 ([`angel3_auth_client`](https://pub.dev/packages/angel3_auth_client)) and Twitter are separate packages on pub.

## Usage

Read the [User Guide](https://angel3-docs.dukefirehawk.com/guides/authentication) first. Then:

1. Create an `AngelAuth`. Its `serializer` turns a user into an id for the JWT, and its `deserializer` turns that id back into a user.
2. Configure the app with it.
3. Register strategies under names, and route `authenticate` with a name.

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

  // Reads the JWT of each request, and gives its user to the handlers.
  await app.configure(auth.configureServer);

  auth.strategies['local'] = LocalAuthStrategy((username, password) {
    // Look the user up. Return them if the password is right, or `null`.
    return null;
  });

  app.post('/auth/local', auth.authenticate('local'));

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

`configureServer` also routes `POST /auth/token`, which exchanges a JWT for a new one (see [Security defaults](#security-defaults)). Configuring the same app again with the same `AngelAuth` does nothing. Configuring it with another `AngelAuth` of the same user type throws.

### Trying several strategies

Give `authenticate` a list of names, or a single comma-separated string such as `'local,basic'`:

```dart
auth.strategies['basic'] =
    LocalAuthStrategy(verifyPasswordSomehow, allowBasic: true);

app.post('/auth/any', auth.authenticate(['local', 'basic']));
```

- The strategies are tried in turn. When one succeeds, the rest are skipped.
- A strategy that fails returns `null`, so the next one is tried.
- A strategy that answers the request itself, such as with a redirect, stops the loop.
- If the last one fails, the answer is a `401 Not Authenticated`, or a redirect to `failureRedirect` if it is given.
- A name that has no strategy throws an `ArgumentError`.

`LocalAuthStrategy` returns `null` when the form has no valid credentials. Invalid Basic credentials, and `forceBasic`, answer a 401 with a Basic challenge.

### What a login answers

Once a strategy succeeds, `authenticate` issues a JWT and sets the `token` cookie. Then it answers in the first way that applies, from the `AngelAuthOptions` you pass it:

1. **`tokenCallback`**, given the `AuthToken` and the user. If it returns something other than `null`, that is the answer. Otherwise the login continues, with any changes the callback made to the token.
2. **`callback`**, given the JWT, such as `confirmPopupAuthentication()` (see [Popup authentication](#popup-authentication)).
3. **`successRedirect`**: a redirect to it.
4. **JSON**: `{"data": user, "token": jwt}`, if the request accepts JSON and `canRespondWithJson` is `true`, which is the default.
5. **`true`** otherwise, so that the next handler runs, as for Basic authentication.

`onLogin` tells you of every new login once it is accepted, however it is answered. It is not told of a login that `tokenCallback` refuses, nor of a user who was already signed in.

To sign a user in from your own code, use `login` with an `AuthToken` you have verified, for example with `AuthToken.validate`, or `loginById` with a user id. Both throw a 403 if the user doesn't exist. If the request already has a user, it keeps that user, and the new one applies from the next request.

### Protecting routes

A handler gets the request's user with `req.container!.makeAsync<User>()`.

- **`requireAuthentication<User>()`** refuses a request without a user with a 403. Called with `throwError: false`, it returns `false` instead.
- **`forceBasicAuth<User>()`** answers a request with no JWT with a 401 and a `WWW-Authenticate: Basic` challenge, so a browser asks for a username and password. Its realm is `angel3_auth` by default; pass `realm` for another one.
- **An invalid JWT**, such as one that has expired, gets a 403 from both.

```dart
app.get('/me', chain([
  requireAuthentication<User>(),
  (req, res) => req.container!.makeAsync<User>(),
]));
```

### Logging out

`logout` expires the `token` cookie, tells `onLogout`, and redirects to `successRedirect` if you give one. No handler after it runs once it has redirected.

```dart
app.post('/auth/logout', auth.logout(AngelAuthOptions(successRedirect: '/')));
```

A JWT is not revoked. A copy of it stays valid until it expires.

## Security defaults

- **JWT lifetime.** A JWT expires after a day. Set `jwtLifeSpan`, in milliseconds, for another lifetime. `-1` means it never expires, and a warning is logged if you also give a fixed `jwtKey`.
- **The JWT key.** Without a `jwtKey`, a random one is made on each start, so JWTs don't survive a restart and differ between instances. Give a fixed key from a secret to share them.
- **Renewing.** `POST /auth/token` exchanges a JWT that is still valid for a new one. An expired JWT is renewed only within `reviveGracePeriod`, which is none by default. The user must still exist.
- **The cookie.** The `token` cookie is `HttpOnly`, `Secure` and `SameSite=Lax`; change `SameSite` with `cookieSameSite`. It is set when a user logs in or a JWT is renewed, not for requests that use an `Authorization: Bearer` header. `logout` expires it.
- **IP address.** With `enforceIp`, which is on by default, a JWT is refused when it is used from a different IP address than the one it was issued to.
- **The query string.** A JWT in the query (`?token=`) is ignored unless `allowTokenInQuery` is `true`, because query strings end up in logs, browser history and `Referer` headers.
- **Claims.** JWTs have `"iss": "angel3_auth"`, and the standard `iat` and `exp` claims in seconds.

## Popup authentication

Single-page apps often open an OAuth login in a separate window. [`angel3_client`](https://pub.dev/packages/angel3_client) supports this, and works with the `confirmPopupAuthentication` callback of this package:

```dart
Future<void> configureServer(Angel app) async {
  app.get(
    '/auth/facebook',
    auth.authenticate(
      'facebook',
      AngelAuthOptions(callback: confirmPopupAuthentication()),
    ),
  );
}
```

It renders a small HTML page that sends the user's JWT to `window.opener` as a `token` event, and closes the window. Pass `eventName` for another event name. `angel3_client` [exposes the event as a Stream](https://pub.dev/documentation/angel3_client/latest/):

```dart
app.authenticateViaPopup('/auth/google').listen((jwt) {
  // Do something with the JWT
});
```

## Migrating from 9.x to 10.0.0

The [CHANGELOG](CHANGELOG.md) lists the breaking changes of each release. These are the ones in 10.0.0 that may need changes in an app:

- **JWT lifetime.** A JWT expires after a day by default (`AngelAuth.defaultJwtLifeSpan`). Pass `jwtLifeSpan`, in milliseconds, for another lifetime. `-1` never expires, and a warning is logged if you also give a fixed `jwtKey`.
- **Renewing JWTs.** `POST /auth/token` renews a JWT that is still valid. It renews an expired one only within `reviveGracePeriod`, which is none by default, and only if its user still exists. Clients that renewed expired JWTs must log in again, unless you give a grace period:

  ```dart
  var auth = AngelAuth<User>(
    serializer: (user) => user.id ?? '',
    deserializer: (id) => fetchAUserByIdSomehow(id),
    reviveGracePeriod: const Duration(days: 7),
  );
  ```

- **Cookie.** The `token` cookie is `SameSite=Lax` (`cookieSameSite`). It is set only when a user logs in or a JWT is renewed, not for requests with an `Authorization: Bearer` header.
- **Token in the query string.** `?token=` is ignored unless `allowTokenInQuery` is `true`. Enable it for the browser WebSocket client of `angel3_websocket`, which cannot send headers.
- **Claims.** JWTs have the standard `iat` and `exp` claims, in seconds. JWTs issued by 9.x are still read.
