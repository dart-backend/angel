# Angel3 Auth Client

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_auth_client?include_prereleases)
![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)(<https://dart.dev/null-safety>)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/security/auth_client/LICENSE)

Angel3 library for authenticating users with remote identity providers via OAuth2, i.e. Facebook, Google, Azure AD, etc. Your server is the OAuth2 client: it redirects users to the provider, and exchanges the code of the callback for a token, with the authorization code grant and PKCE. For an OAuth2 authorization server, see [`angel3_auth_server`](https://pub.dev/packages/angel3_auth_server).

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_auth_client: ^10.0.0
```

## Usage

First, create an options object:

```dart
// Load from a Map, i.e. app config:
ExternalAuthOptions optionsOf(Angel app) => ExternalAuthOptions.fromMap(
    app.configuration['auth0'] as Map<String, dynamic>);

// Or create in-place:
var options = ExternalAuthOptions(
    clientId: '<client-id>',
    clientSecret: '<client-secret>',
    redirectUri: Uri.parse('<callback>'));
```

After getting authenticated against the remote server, we need to be able to identify users within our own application.

```dart
/// You might use a pure function to create a verifier that queries a
/// given service.
FutureOr<User> Function(oauth2.Client, RequestContext, ResponseContext)
    oauth2verifier(Service<String, User> userService) {
  return (client, req, res) async {
    var response = await client.get(Uri.parse('https://api.github.com/user'));
    var ghUser = json.decode(response.body) as Map;
    var id = ghUser['id'] as int;

    var matchingUsers = await userService.index({
      'query': {'github_id': id}
    });

    if (matchingUsers.isNotEmpty) {
      // Return the corresponding user, if it exists.
      return matchingUsers.first;
    } else {
      // Otherwise, create a user
      return await userService.create(User(githubId: id));
    }
  };
}
```

Now, initialize an `OAuth2Strategy`, using the options and verifier. You'll also need to provide a name for this instance of the strategy. Consider using the name of the remote authentication provider (ex. `facebook`).

```dart
configureServer(Angel app) {
  auth.strategies['github'] = OAuth2Strategy(
    options,
    authorizationEndpoint,
    tokenEndpoint,
    yourVerifier,

    // This function is called when an error occurs, or the user REJECTS the request.
    (e, req, res) async {
      res.write('Ooops: $e');
      await res.close();
    },
  );
}
```

Lastly, connect it to an `AngelAuth` instance, and wire it up to an `Angel` server. Set up two routes:

  1. Redirect users to the external provider
  2. Acts as a callback and handles an access code
  
The strategy tells the two apart by the request: one with a `code` or `error` query parameter is the provider's callback. Each login gets its own random `state`, against login CSRF, and PKCE code verifier. Both are kept until the callback in a signed, `HttpOnly` cookie of each login (`cookieName`, default `angel3_oauth2`, followed by the start of its `state`), scoped to the path of the redirect URI, which expires after `loginTimeout` (default 10 minutes). The cookie is signed with a key derived from the client secret, so every instance of the app accepts it; pass `cookieKey` to use another, as a client without a secret must for more than one instance. It is `SameSite=Lax` (`cookieSameSite`), which a provider's redirect back carries; a provider that posts its callback (`response_mode=form_post`, asked for with `authorizationParameters`, below) needs `SameSite.none`, over HTTPS, and a `post` route for the callback. Only the result of the verifier signs a user in, never that of `onError`. A callback of no login started here, or of another `state`, goes to `onError` as `invalid_state`, and a malformed one, as of a posted body that cannot be read, as `invalid_request`. A browser may have `maxLogins` logins in progress at once (default 5), as of several tabs; starting another expires the cookies of the oldest, so that those the callback is sent stay few. The strategy warns of settings with which every login fails: `response_mode=form_post` without `SameSite.none`, and `SameSite.none` of an `http` redirect URI, whose cookie browsers drop. A provider that cannot be reached is a `502`. `onError` should write a response, or redirect; a value it returns is sent as the response. The `oauth2.Client` given to the verifier is closed once it returns, unless you passed an `httpClient`.

In the case of the callback route, you may want to display an HTML page that closes a popup window. In this case, use `confirmPopupAuthentication`, which is bundled with `package:angel3_auth`, as a `callback` function:

```dart
configureServer(Angel app) async {
  var auth = AngelAuth<User>(
    serializer: (user) => user.id!,
    deserializer: (id) => userService.read(id),
  );
  auth.strategies['github'] = oauth2Strategy;
  
  // Redirect
  app.get('/auth/github', auth.authenticate('github'));
  
  // Callback
  app.get('/auth/github/callback', auth.authenticate(
    'github',
    AngelAuthOptions(callback: confirmPopupAuthentication())
  ));
  
  // Connect the plug-in!!!
  await app.configure(auth.configureServer);
}
```

## Custom Scope Delimiter

This package should work out-of-the-box for most OAuth2 providers, such as Github or Dropbox. However, if your OAuth2 scopes are separated by a delimiter other than the default (`' '`), you can add it in the `OAuth2Strategy` constructor:

```dart
var strategy = OAuth2Strategy(
  options,
  authorizationEndpoint,
  tokenEndpoint,
  yourVerifier,
  yourErrorHandler,
  delimiter: ',',
);
```

## Handling non-JSON responses

Many OAuth2 providers do not follow the specification, and do not return `application/json` responses.

You can add a `getParameters` callback to parse the contents of any arbitrary response:

```dart
var strategy = OAuth2Strategy(
    options,
    authorizationEndpoint,
    tokenEndpoint,
    yourVerifier,
    yourErrorHandler,
    getParameters: (contentType, body) {
      if (contentType?.type == 'application') {
        if (contentType!.subtype == 'x-www-form-urlencoded') {
          return Uri.splitQueryString(body);
        } else if (contentType.subtype == 'json') {
          return json.decode(body) as Map<String, dynamic>;
        }
      }

      throw FormatException('Invalid content-type $contentType; expected application/x-www-form-urlencoded or application/json.');
    }
);
```

## Keeping the tokens

The `oauth2.Client` given to the verifier is closed once it returns. To call the provider's API later, keep its credentials, which hold the access token, and the refresh token if the provider gave one. Then make a client of them with `package:oauth2`, which refreshes the access token when it expires. Give it the client secret and `basicAuth` of the strategy, so that it sends them to the token endpoint as the strategy does:

```dart
import 'dart:convert';

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_auth_client/angel3_auth_client.dart';
import 'package:oauth2/oauth2.dart' as oauth2;

/// The credentials of each user, by id: a table of a database in an app.
final savedCredentials = <String, String>{};

OAuth2Strategy<String> githubStrategy(ExternalAuthOptions options) =>
    OAuth2Strategy(
      options,
      Uri.parse('https://github.com/login/oauth/authorize'),
      Uri.parse('https://github.com/login/oauth/access_token'),
      (client, req, res) async {
        var profile = json.decode(
          await client.read(Uri.parse('https://api.github.com/user')),
        );
        var userId = '${profile['id']}';
        savedCredentials[userId] = client.credentials.toJson();
        return userId;
      },
      (e, req, res) => res.redirect('/login'),
    );

/// A client of the provider's API for [userId], which refreshes the access
/// token when it expires, and saves the new credentials.
oauth2.Client clientOf(OAuth2Strategy strategy, String userId) => oauth2.Client(
  oauth2.Credentials.fromJson(savedCredentials[userId]!),
  identifier: strategy.options.clientId,
  secret: strategy.options.clientSecret.isEmpty
      ? null
      : strategy.options.clientSecret,
  // As the strategy sends them to the token endpoint.
  basicAuth: strategy.basicAuth,
  onCredentialsRefreshed: (credentials) =>
      savedCredentials[userId] = credentials.toJson(),
);
```

## More parameters of the authorization URL

Some providers take more query parameters, such as `access_type=offline` for a refresh token of Google, `prompt`, or `response_mode=form_post` of Sign in with Apple. Pass them as `authorizationParameters`; they do not replace those of the strategy (`client_id`, `redirect_uri`, `scope`, `state`, and those of PKCE), which are dropped, with a warning; give scopes in the `ExternalAuthOptions` instead:

```dart
var strategy = OAuth2Strategy(
  options,
  authorizationEndpoint,
  tokenEndpoint,
  yourVerifier,
  yourErrorHandler,
  authorizationParameters: {'access_type': 'offline', 'prompt': 'consent'},
);
```

## Client authentication at the token endpoint

The client ID and secret are sent to the token endpoint with HTTP Basic authentication (`client_secret_basic`). For a provider that wants them in the form of the request (`client_secret_post`), pass `basicAuth: false`.

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **State and PKCE**: each login has a random `state` and a PKCE code verifier, kept until the callback in a signed, `HttpOnly` cookie of its own, which expires after `loginTimeout` (default 10 minutes). A callback without it, or of another `state`, goes to `onError` as `invalid_state`. Start every login at the redirect route of the strategy, so that the cookie is set; a provider that posts its callback (`response_mode=form_post`) needs `cookieSameSite: SameSite.none`, over HTTPS.
* **Several instances**: the cookie is signed with a key derived from the client secret. A client without a secret signs with a random key, so give it a `cookieKey` when it runs as more than one instance.
