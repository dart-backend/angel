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

It depends on [`jose_plus`](https://pub.dev/packages/jose_plus), and on its `pointycastle`, `crypto_keys_plus` and `x509_plus`, of which it checks the signatures of the ID tokens of [OpenID Connect](#openid-connect) providers. They are pure Dart, and an app that signs in of no OpenID provider compiles none of their code, but pub resolves them all the same: a version conflict of `pointycastle` or `asn1lib` with another package of the app is of them.

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
FutureOr<User?> Function(oauth2.Client, RequestContext, ResponseContext)
    oauth2verifier(Service<String, User> userService) {
  return (client, req, res) async {
    var response = await client.get(Uri.parse('https://api.github.com/user'));
    // Refuse a login of no user, as of bad credentials or a rate limit.
    if (response.statusCode != 200) return null;
    var id = (json.decode(response.body) as Map)['id'];
    if (id is! int) return null;

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
  
The strategy tells the two apart by the request: one with an `error` query parameter, or with a `code` and a `state`, is the provider's callback; any other, as a link of a `code` of its own, starts a login. Each login gets its own random `state`, against login CSRF, and PKCE code verifier. Both are kept until the callback in a signed, `HttpOnly` cookie of each login (`cookieName`, default `angel3_oauth2`, followed by the start of its `state`), scoped to the path that the route that starts the login shares with the redirect URI, such as `/auth/github` of `/auth/github` and `/auth/github/callback`, so that both are sent it, which expires after `loginTimeout` (default 10 minutes). Mount the two routes under one path: of unrelated ones, such as `/login` and `/auth/callback`, the cookies are of `/`, and sent with every request to the app until they expire. Behind a proxy that maps another path to the app's, such as `https://host/app/auth/github` to `/auth/github`, give the browser's path as `cookiePath`, such as `/app/auth/github`. The cookie is signed with a key derived from the client secret, so every instance of the app accepts it; pass `cookieKey`, of at least 16 bytes, to use another, as a client without a secret must for more than one instance, or more than one isolate. It is `SameSite=Lax` (`cookieSameSite`), which a provider's redirect back carries; a provider that posts its callback (`response_mode=form_post`, asked for with `authorizationParameters`, below) needs `SameSite.none`, over HTTPS, and a `post` route for the callback. Only the result of the verifier signs a user in, never that of `onError`. A callback of no login started here, or of another `state`, goes to `onError` as `invalid_state`, and a malformed one as `invalid_request`; so does a posted callback whose body cannot be read, of a strategy of `response_mode=form_post`, given in `authorizationParameters` or in the query of the authorization endpoint, while a posted form that starts a login is of its query alone. A browser may have `maxLogins` logins in progress at once (default 5), as of several tabs; starting another, or finishing one, expires the cookies of the oldest beyond, so that those the callback is sent stay few. Only cookies of logins that the strategy started are expired, not those of another strategy of the same `cookieName`, or of another client signed with the same `cookieKey`, and a callback of no login of the browser, as of a crafted link, expires none. The constructor refuses settings with which every login fails, with an `ArgumentError`: `response_mode=form_post` without `SameSite.none`, and a `cookiePath` that is not the redirect URI's path or above it; it warns of `SameSite.none` of an `http` redirect URI, whose cookie browsers drop. A refusal of the provider, as `access_denied`, of a login of the browser that timed out, is that refusal, not `invalid_state`. The token endpoint has `tokenTimeout` (default 30 seconds) to answer, after which the callback is a `502`. A provider that cannot be reached, or whose token response cannot be read, as an error page of its own, is a `502`. The verifier may return `null` to refuse a user, which `AngelAuth` answers as any failed login. `onError` should write a response, or redirect; a value it returns is sent as the response, and a response it writes but does not close is closed, so that `AngelAuth` does not answer it again. The `oauth2.Client` given to the verifier is of the strategy's HTTP client, your `httpClient` or one of the strategy's own, which every login shares, so that its connections to the provider are kept; closing it in the verifier does nothing, of yours too, which you close yourself; `close()` closes the strategy, as when the app shuts down, and its own client: a request to it after is a `503`.

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

## OpenID Connect

Of an OpenID Provider, such as Google, Microsoft or an `angel3_oidc_server` of your own, the strategy checks the ID token of each login, which tells who signed in. Discover the provider, of its issuer, and give the strategy its `openId`, of the `openid` scope:

```dart
var provider = await OpenIdOptions.discover(Uri.parse('https://accounts.google.com'));
var strategy = OAuth2Strategy<User>(
  ExternalAuthOptions(
    clientId: '<client-id>',
    clientSecret: '<client-secret>',
    redirectUri: Uri.parse('https://app.example/auth/google/callback'),
    scopes: ['openid', 'email'],
  ),
  provider.authorizationEndpoint,
  provider.tokenEndpoint,
  (client, req, res) async {
    var idToken = req.container!.make<IdToken>();
    // Know the user by their issuer and subject, which never change.
    return findOrCreateUserSomehow(idToken.issuer, idToken.subject);
  },
  yourErrorHandler,
  openId: provider.openId,
);
```

Each login then sends a `nonce` of its own, kept in its cookie, and its ID token must be of a key of the provider's JSON Web Key Set, of the `RS256` or `ES256` that `OpenIdOptions.algorithms` accept (never `none`, nor `HS256`, of a secret the app has), of the provider's issuer, of this app's `client_id` as its audience (and as its `azp`, of several audiences), unexpired, not issued ahead of now (of `clockSkew`, default 2 minutes, either way), of the `nonce` of its login, and of the `at_hash` of its access token, if it has one, or the callback goes to `onError` as `invalid_token`. The verifier is given the checked `IdToken` in `req.container`. A provider that gives no ID token is `invalid_token` too; keys that cannot be fetched are a `502`.

The keys are fetched once, and again after `keysLifetime` (default an hour), or at once of a token of a key that is not among them, as when the provider rotates its keys; of such tokens, at most once a minute. Logins that need the keys at once share one fetch of them, and of a fetch after `keysLifetime` that fails, as of a short outage of the provider, the keys fetched before are kept. The configuration must be of the issuer it was discovered of, exactly, and of a JSON Web Key Set, and its URLs, as the issuer's and the `jwksUri` of `OpenIdOptions`, must be `https`, or `http` of localhost; `discover` gives up after its `timeout` (default 30 seconds). Give `OpenIdOptions` yourself, of the `issuer` and `jwksUri`, to use none.

A login that was started before the strategy was given `openId` has no `nonce`, and is refused as `invalid_token`: its user signs in again.

To sign a user out of the provider too, once the app has signed them out of itself, keep the `IdToken.token` of their login, and redirect them to the provider's `endSessionUrl` (OpenID Connect RP-Initiated Logout 1.0), of a `postLogoutRedirectUri` that the app registered with the provider, to which it redirects them after, with the `state`:

```dart
var url = provider.endSessionUrl(
  idTokenHint: session.idToken,
  postLogoutRedirectUri: Uri.parse('https://app.example/signed-out'),
  state: 'bye',
);
await res.redirect(url);
```

It throws a `StateError` of a provider of no `end_session_endpoint`.

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

Keep the credentials of the `oauth2.Client` given to the verifier, not the client, which is of the strategy's. To call the provider's API later, keep its credentials, which hold the access token, and the refresh token if the provider gave one. Then make a client of them with `package:oauth2`, which refreshes the access token when it expires. Give it the client secret and `basicAuth` of the strategy, so that it sends them to the token endpoint as the strategy does:

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
      // GitHub answers the token request as a form, unless asked for JSON,
      // which package:oauth2 does not ask for.
      getParameters: (contentType, body) => contentType?.subtype == 'json'
          ? json.decode(body) as Map<String, dynamic>
          : Uri.splitQueryString(body),
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
* **Several instances**: the cookie is signed with a key derived from the client secret. A client without a secret signs with a random key, so give it a `cookieKey` when it runs as more than one instance, or more than one isolate.

## Migrating from `angel3_auth_oauth2` 10.0.0

This package is `angel3_auth_oauth2`, renamed. Its 10.0.0 also has these changes since `angel3_auth_oauth2` 10.0.0:

* **The name**: depend on `angel3_auth_client`, and import `package:angel3_auth_client/angel3_auth_client.dart`. The classes keep their names.
* **The cookie of a login** is scoped to the path that the route that starts the login shares with the redirect URI, where it was of the redirect URI's path; mount the two routes under one path, such as `/auth/github` and `/auth/github/callback`. Logins in progress during the upgrade still complete: their cookies are read, and the default `cookieKey` is the same. Behind a proxy that maps another path to the app's, give the browser's path as `cookiePath`.
* **`maxLogins`** (default 5): a browser may have that many logins in progress; starting or finishing one expires the cookies of the oldest beyond. `maxLogins` must be at least 1, and `loginTimeout` at least a second, or the constructor throws an `ArgumentError`.
* **New options**: `authorizationParameters`, more query parameters of the authorization URL, and `basicAuth: false`, to send the client secret in the form.
* **Errors of `onError`**: a callback without a `code` is `invalid_request`, as is a posted callback whose body cannot be read, of `response_mode=form_post`; a `state` that the strategy did not give, as of a crafted link, is `invalid_state`. A token response that cannot be read, as an error page of the provider, is a 502, as is a provider that cannot be reached, where it was `invalid_request`.
* **The verifier** may return `null` to refuse a user.
* **OpenID Connect**: `openId`, of `OpenIdOptions.discover`, checks the ID token of each login, of a `nonce` of its own, and gives the verifier the `IdToken`.
* **A client without a secret** sends its `client_id` alone to the token endpoint, rather than an empty secret.

The [CHANGELOG](CHANGELOG.md) lists them all.
