# Angel3 Twitter OAuth1

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_auth_twitter?include_prereleases)
![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](<https://dart.dev/null-safety>)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/auth_twitter/LICENSE)

Angel3 authentication strategy using Twitter OAuth 1.0a.

## Installation

This package is not published on pub.dev. Depend on it from the repository, adding a `ref:` for a branch or a tag:

```yaml
dependencies:
  angel3_auth_twitter:
    git:
      url: https://github.com/dart-backend/angel.git
      path: packages/auth_twitter
```

## Usage

`TwitterStrategy` signs users in with Twitter's OAuth 1.0a redirect flow: a request without Twitter's callback parameters is redirected to Twitter, and the callback signs the user in.

```dart
auth.strategies['twitter'] = TwitterStrategy(
  ExternalAuthOptions(
    clientId: '<consumer key>',
    clientSecret: '<consumer secret>',
    redirectUri: 'http://localhost:3000/auth/twitter/callback',
  ),
  // Find or create the user of the Twitter account.
  (twit, req, res) async {
    var response = await twit.client.get(
      Uri.parse('https://api.twitter.com/1.1/account/verify_credentials.json'),
    );
    var userData = json.decode(response.body) as Map;
    return User(userData['screen_name'] as String);
  },
  // When an error occurs, i.e. the user declines to approve the application.
  (e, req, res) async {
    res.write(e.isDenial ? "Why'd you say no???" : 'oops: ${e.message}');
  },
);

app.get('/auth/twitter', auth.authenticate('twitter'));
app.get(
  '/auth/twitter/callback',
  auth.authenticate(
    'twitter',
    AngelAuthOptions(callback: (req, res, jwt) => res.redirect('/home?token=$jwt')),
  ),
);
```

See the [example](example/example.dart) for a complete app.

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **Redirect flow**: `TwitterStrategy` uses the OAuth 1.0a redirect flow, instead of asking for a PIN on `stdin` in its constructor. Mount it on a route that redirects to Twitter, and on the callback route, as for other strategies; see the [example](example/example.dart).
* **Credentials**: the `client` getter is removed. The consumer credentials are in `authorization`.
* **Errors**: `authenticateCallback` throws a `TwitterAuthorizationException` instead of returning the result of `onError`, and `authenticate` runs that result as a handler.
