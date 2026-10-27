# Angel3 OAuth2 Handler

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_auth_oauth2?include_prereleases)
![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)(<https://dart.dev/null-safety>)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/auth_oauth2/LICENSE)

Angel3 library for authenticating users with remote identity providers via OAuth2, i.e. Facebook, Google, Azure AD, etc.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_auth_oauth2: ^10.0.0
```

## Usage

First, create an options object:

```dart
configureServer(Angel app) async {
  // Load from a Map, i.e. app config:
  var opts = ExternalAuthOptions.fromMap(app.configuration['auth0'] as Map);
  
  // Create in-place:
  var opts = ExternalAuthOptions(
      clientId: '<client-id>',
      clientSecret: '<client-secret>',
      redirectUri: Uri.parse('<callback>'));
}
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
  
The strategy tells the two apart by the request: one with a `code` or `error` query parameter is the provider's callback. Each login gets its own random `state`, against login CSRF, and PKCE code verifier. Both are kept until the callback in a signed, `HttpOnly` cookie of each login (`cookieName`, default `angel3_oauth2`, followed by the start of its `state`), scoped to the path of the redirect URI, which expires after `loginTimeout` (default 10 minutes). The cookie is signed with a key derived from the client secret, so every instance of the app accepts it; pass `cookieKey` to use another, as a client without a secret must for more than one instance. It is `SameSite=Lax` (`cookieSameSite`), which a provider's redirect back carries; a provider that posts its callback (`response_mode=form_post`) needs `SameSite.none`, over HTTPS, and a `post` route for the callback. Only the result of the verifier signs a user in, never that of `onError`. A callback of no login started here, or of another `state`, goes to `onError` as `invalid_state`, and a malformed one as `invalid_request`. A provider that cannot be reached is a `502`. `onError` should write a response, or redirect; a value it returns is sent as the response. The `oauth2.Client` given to the verifier is closed once it returns, unless you passed an `httpClient`.

In the case of the callback route, you may want to display an HTML page that closes a popup window. In this case, use `confirmPopupAuthentication`, which is bundled with `package:angel3_auth`, as a `callback` function:

```dart
configureServer(Angel app) async {
  // ...
  var auth = AngelAuth<User>();
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
configureServer(Angel app) async {
  OAuth2Strategy(..., delimiter: ',');
}
```

## Handling non-JSON responses

Many OAuth2 providers do not follow the specification, and do not return `application/json` responses.

You can add a `getParameters` callback to parse the contents of any arbitrary response:

```dart
OAuth2Strategy(
    // ...
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

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

* **State and PKCE**: each login has a random `state` and a PKCE code verifier, kept until the callback in a signed, `HttpOnly` cookie of its own, which expires after `loginTimeout` (default 10 minutes). A callback without it, or of another `state`, goes to `onError` as `invalid_state`. Start every login at the redirect route of the strategy, so that the cookie is set; a provider that posts its callback (`response_mode=form_post`) needs `cookieSameSite: SameSite.none`, over HTTPS.
* **Several instances**: the cookie is signed with a key derived from the client secret. A client without a secret signs with a random key, so give it a `cookieKey` when it runs as more than one instance.
