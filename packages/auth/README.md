# Angel3 Anthentication

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_auth?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/auth/LICENSE)

A complete authentication plugin for Angel3. Inspired by Passport. More details in the [User Guide](https://angel3-docs.dukefirehawk.com/guides/authentication).

## Bundled Strategies

* Local (with and without Basic Auth)
* Find other strategies (Twitter, Google, OAuth2, etc.) on pub

## Example

Ensure you have read the [User Guide](https://angel3-docs.dukefirehawk.com/guides/authentication).

```dart
configureServer(Angel app) async {
  var auth = AngelAuth<User>(
    serializer: (user) => user.id ?? '',
    deserializer: (id) => fetchAUserByIdSomehow(id
  );
  auth.strategies['local'] = LocalAuthStrategy(...);
  
  // POST route to handle username+password
  app.post('/local', auth.authenticate('local'));

  // Using Angel's asynchronous injections, we can parse the JWT
  // on demand. It won't be parsed until we check.
  app.get('/profile', ioc((User user) {
    print(user.description);
  }));
  
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
  
  // Apply angel_auth-specific configuration.
  await app.configure(auth.configureServer);
}
```

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
