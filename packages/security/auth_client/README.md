# Angel3 Auth Client

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_auth_client?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/security/auth_client/LICENSE)

Sign users in to an Angel3 app with an external OAuth2 provider, such as GitHub, Google, Microsoft Entra ID or Auth0. Your server is the OAuth2 client: it redirects the user to the provider, then exchanges the code the provider sends back for a token, using the authorization code grant with PKCE. With an OpenID Connect provider, it also checks the ID token that says who signed in.

To build an OAuth2 authorization server instead, see [`angel3_auth_server`](https://pub.dev/packages/angel3_auth_server).

- [Angel3 Auth Client](#angel3-auth-client)
  - [Installation](#installation)
  - [Usage](#usage)
  - [How a login works](#how-a-login-works)
    - [Routes and cookies](#routes-and-cookies)
    - [Several instances](#several-instances)
    - [Errors](#errors)
    - [The HTTP client](#the-http-client)
  - [OpenID Connect](#openid-connect)
    - [Signing out](#signing-out)
  - [Keeping the tokens](#keeping-the-tokens)
  - [More parameters of the authorization URL](#more-parameters-of-the-authorization-url)
  - [Client authentication at the token endpoint](#client-authentication-at-the-token-endpoint)
    - [Mutual TLS](#mutual-tls)
  - [Custom scope delimiter](#custom-scope-delimiter)
  - [Handling non-JSON responses](#handling-non-json-responses)
  - [Migrating from 9.x to 10.0.0](#migrating-from-9x-to-1000)
  - [Migrating from `angel3_auth_oauth2` 10.0.0](#migrating-from-angel3_auth_oauth2-1000)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_auth_client: ^10.0.0
```

It depends on [`jose_plus`](https://pub.dev/packages/jose_plus), and through it on `pointycastle`, `crypto_keys_plus` and `x509_plus`, which check the signatures of ID tokens from [OpenID Connect](#openid-connect) providers. They are pure Dart, and an app that doesn't use OpenID Connect compiles none of their code. Pub still resolves them, though, so a version conflict over `pointycastle` or `asn1lib` with another of your packages comes from them.

## Usage

First, create the options of your client, as registered with the provider:

```dart
// Load them from the app's configuration:
ExternalAuthOptions optionsOf(Angel app) => ExternalAuthOptions.fromMap(
    app.configuration['github'] as Map<String, dynamic>);

// Or create them in place:
var options = ExternalAuthOptions(
  clientId: '<client-id>',
  clientSecret: '<client-secret>',
  redirectUri: Uri.parse('https://app.example/auth/github/callback'),
);
```

Then write a verifier, which turns a signed-in provider account into a user of your app. It is given an `oauth2.Client` that calls the provider's API with the user's access token. Return `null` to refuse the user:

```dart
FutureOr<User?> Function(oauth2.Client, RequestContext, ResponseContext)
    githubVerifier(Service<String, User> userService) {
  return (client, req, res) async {
    var response = await client.get(Uri.parse('https://api.github.com/user'));
    // Refuse the login if there is no user, as with bad credentials or a
    // rate limit.
    if (response.statusCode != 200) return null;
    var id = (json.decode(response.body) as Map)['id'];
    if (id is! int) return null;

    var matchingUsers = await userService.index({
      'query': {'github_id': id}
    });
    if (matchingUsers.isNotEmpty) return matchingUsers.first;
    return await userService.create(User(githubId: id));
  };
}
```

Create an `OAuth2Strategy` from the options, the provider's endpoints, the verifier, and an `onError` handler. `onError` is called when the login fails, including when the user declines it at the provider. Register the strategy with `AngelAuth` under a name, usually the provider's, and route two paths to it, one to start the login and one for the provider's callback:

```dart
Future<void> configureServer(Angel app) async {
  var auth = AngelAuth<User>(
    serializer: (user) => user.id!,
    deserializer: (id) => userService.read(id),
  );
  auth.strategies['github'] = OAuth2Strategy(
    options,
    Uri.parse('https://github.com/login/oauth/authorize'),
    Uri.parse('https://github.com/login/oauth/access_token'),
    githubVerifier(userService),
    (e, req, res) async {
      res.write('Ooops: $e');
      await res.close();
    },
  );

  // Starts the login: redirects the user to GitHub.
  app.get('/auth/github', auth.authenticate('github'));

  // The callback, of the redirect URI: signs the user in.
  app.get(
    '/auth/github/callback',
    auth.authenticate(
      'github',
      // To close a popup window once the user signed in, as of
      // `package:angel3_auth`.
      AngelAuthOptions(callback: confirmPopupAuthentication()),
    ),
  );

  await app.configure(auth.configureServer);
}
```

## How a login works

The strategy tells the two routes apart by the request. A request with an `error` query parameter, or with both a `code` and a `state`, is the provider's callback. Any other request starts a login, even one with a `code` of its own, as from a link.

Each login gets its own random `state`, which protects against login CSRF, and its own PKCE code verifier. Only the verifier's result signs a user in, never `onError`'s.

### Routes and cookies

The `state` and code verifier are kept until the callback in a signed, `HttpOnly` cookie, one per login. It is named after `cookieName` (default `angel3_oauth2`) followed by the start of the `state`, and it expires after `loginTimeout` (default 10 minutes).

The cookie's path is the part of the path that the route starting the login shares with the redirect URI, so both routes are sent it. For `/auth/github` and `/auth/github/callback`, it is `/auth/github`. So mount the two routes under one path. With unrelated paths, such as `/login` and `/auth/callback`, the cookie's path is `/`, and it is sent with every request to the app until it expires.

Behind a proxy that maps another path to the app's, such as `https://host/app/auth/github` to `/auth/github`, give the browser's path as `cookiePath`, here `/app/auth/github`.

The cookie is `SameSite=Lax` (`cookieSameSite`), which the provider's redirect back still carries. A provider that posts its callback instead (`response_mode=form_post`, asked for with [`authorizationParameters`](#more-parameters-of-the-authorization-url)) needs `SameSite.none`, over HTTPS, and a `post` route for the callback.

A browser may have up to `maxLogins` logins in progress at once (default 5), as from several tabs. Starting or finishing another expires the cookies of the oldest ones beyond that, so that few cookies are sent. The strategy only expires cookies of logins it started itself. It leaves alone those of another strategy with the same `cookieName`, or of another client signed with the same `cookieKey`. A callback that matches no login of the browser, as from a crafted link, expires none.

The constructor throws an `ArgumentError` for settings with which every login would fail:

- `response_mode=form_post` without `SameSite.none`;
- a `cookiePath` that is not the redirect URI's path or above it;
- a `maxLogins` under 1, or a `loginTimeout` under a second.

It logs a warning for `SameSite.none` with an `http` redirect URI, since browsers drop such a cookie.

### Several instances

The cookie is signed with a key derived from the client secret, so every instance of the app accepts the cookies of the others. To sign with another key, pass a `cookieKey` of at least 16 bytes. A client without a secret must do so if it runs as more than one instance, or in more than one isolate, as it otherwise signs with a random key.

### Errors

These go to `onError`:

- **`invalid_state`:** a callback of no login started here, or with another `state`.
- **`invalid_request`:** a malformed callback, such as one without a `code`. This includes a posted callback whose body can't be read, when the strategy uses `response_mode=form_post`, given in `authorizationParameters` or in the query of the authorization endpoint. A posted form that starts a login is read from its query alone.
- **The provider's refusal,** such as `access_denied`, even when the login's cookie has expired. It is not reported as `invalid_state`.
- **`502`:** the provider can't be reached, the token endpoint doesn't answer within `tokenTimeout` (default 30 seconds), or its token response can't be read, such as an error page of its own.

If the verifier returns `null`, `AngelAuth` answers as for any failed login.

`onError` should write a response or redirect. A value it returns is sent as the response. A response it writes but doesn't close is closed for it, so that `AngelAuth` doesn't answer it again.

### The HTTP client

The `oauth2.Client` given to the verifier uses the strategy's HTTP client: your `httpClient`, or the strategy's own. Every login shares it, so connections to the provider are kept open. Closing the `oauth2.Client` in the verifier does nothing, even with your own `httpClient`, which you close yourself.

Call `close()` when the app shuts down. It closes the strategy and its own HTTP client, and any request to the strategy after that is a `503`.

## OpenID Connect

With an OpenID Provider, such as Google, Microsoft, or your own `angel3_oidc_server`, the strategy also checks the ID token of each login, which says who signed in. Discover the provider from its issuer, ask for the `openid` scope, and give the strategy the provider's `openId`:

```dart
var provider =
    await OpenIdOptions.discover(Uri.parse('https://accounts.google.com'));
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

Each login then sends a `nonce` of its own, kept in its cookie. The ID token must:

- be signed by a key in the provider's JSON Web Key Set, with an algorithm of `OpenIdOptions.algorithms`, `RS256` or `ES256`. `none` and `HS256` are never accepted;
- be from the provider's issuer;
- have this app's `client_id` as its audience, and as its `azp` if it has several audiences;
- not be expired, nor issued in the future, allowing `clockSkew` (default 2 minutes) either way;
- have the `nonce` of its login;
- match the access token's `at_hash`, if it has one.

Otherwise the callback goes to `onError` as `invalid_token`, as it does when the provider gives no ID token. Keys that can't be fetched are a `502`. The verifier finds the checked `IdToken` in `req.container`.

The keys are fetched once, and again after `keysLifetime` (default an hour). They're also fetched at once for a token signed by a key that isn't among them, as when the provider rotates its keys, but at most once a minute. Logins waiting for the keys share one fetch. If a fetch after `keysLifetime` fails, as during a short outage of the provider, the previous keys are kept.

The provider's configuration must name exactly the issuer it was discovered from, and give a JSON Web Key Set. Its URLs, like the issuer and the `jwksUri` of `OpenIdOptions`, must be `https`, or `http` on localhost. `discover` gives up after its `timeout` (default 30 seconds). To skip discovery, build `OpenIdOptions` yourself from the `issuer` and `jwksUri`.

A login started before the strategy was given `openId` has no `nonce`, so it is refused as `invalid_token`, and the user signs in again.

### Signing out

To sign a user out of the provider too, keep the `IdToken.token` of their login. Once the app has signed them out of itself, redirect them to the provider's `endSessionUrl` (OpenID Connect RP-Initiated Logout 1.0). Give a `postLogoutRedirectUri` that the app registered with the provider. The provider redirects the user there afterwards, with the `state`:

```dart
var url = provider.endSessionUrl(
  idTokenHint: session.idToken,
  postLogoutRedirectUri: Uri.parse('https://app.example/signed-out'),
  state: 'bye',
);
await res.redirect(url);
```

`endSessionUrl` throws a `StateError` if the provider has no `end_session_endpoint`.

## Keeping the tokens

To call the provider's API later, keep the credentials of the `oauth2.Client` given to the verifier, not the client itself, which belongs to the strategy. The credentials hold the access token, and the refresh token if the provider gave one. Later, build a client from them with `package:oauth2`, which refreshes the access token when it expires. Give it the client secret and the strategy's `basicAuth`, so that it authenticates to the token endpoint as the strategy does:

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

Some providers take more query parameters, such as `access_type=offline` for a Google refresh token, `prompt`, or `response_mode=form_post` for Sign in with Apple. Pass them as `authorizationParameters`. They can't replace the strategy's own parameters (`client_id`, `redirect_uri`, `scope`, `state` and those of PKCE): those are dropped, with a warning. Give scopes in the `ExternalAuthOptions` instead.

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

The client ID and secret are sent to the token endpoint with HTTP Basic authentication (`client_secret_basic`). For a provider that wants them in the form of the request (`client_secret_post`), pass `basicAuth: false`. A client without a secret sends its `client_id` alone.

### Mutual TLS

For a provider that authenticates clients by a TLS client certificate (RFC 8705), give the strategy an `httpClient` whose `SecurityContext` has the client's certificate and key, and an empty `clientSecret`. The token requests then go over a connection with the certificate, and send the `client_id` alone:

```dart
var context = SecurityContext()
  ..useCertificateChain('client.pem')
  ..usePrivateKey('client.key');
var strategy = OAuth2Strategy(
  ExternalAuthOptions(
    clientId: '<client-id>',
    clientSecret: '',
    redirectUri: Uri.parse('https://app.example/auth/example/callback'),
  ),
  Uri.parse('https://id.example.com/oauth2/authorize'),
  // The `mtls_endpoint_aliases` of the provider's metadata, if it has them.
  Uri.parse('https://mtls.example.com/oauth2/token'),
  verifier,
  onError,
  httpClient: IOClient(HttpClient(context: context)),
);
```

If the provider binds access tokens to the certificate, the verifier's `oauth2.Client` also calls the provider's API with it, so the API accepts them.

## Custom scope delimiter

Scopes are separated by a space by default, as OAuth2 specifies. For a provider that uses another delimiter, pass it as `delimiter`:

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

Some providers don't answer the token request with `application/json`, as the specification requires. Pass a `getParameters` callback to parse any response:

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
    throw FormatException(
        'Invalid content-type $contentType; expected '
        'application/x-www-form-urlencoded or application/json.');
  },
);
```

## Migrating from 9.x to 10.0.0

The [CHANGELOG](CHANGELOG.md) lists the breaking changes of each release. These 10.0.0 changes may need changes in an app:

- **State and PKCE:** each login has a random `state` and a PKCE code verifier, kept until the callback in a signed, `HttpOnly` cookie of its own, which expires after `loginTimeout` (default 10 minutes). A callback without the cookie, or with another `state`, goes to `onError` as `invalid_state`. Start every login at the strategy's redirect route, so that the cookie is set. A provider that posts its callback (`response_mode=form_post`) needs `cookieSameSite: SameSite.none`, over HTTPS.
- **Several instances:** the cookie is signed with a key derived from the client secret. A client without a secret signs with a random key, so give it a `cookieKey` when it runs as more than one instance, or in more than one isolate.

## Migrating from `angel3_auth_oauth2` 10.0.0

This package is `angel3_auth_oauth2`, renamed. Its 10.0.0 also has these changes since `angel3_auth_oauth2` 10.0.0:

- **The name:** depend on `angel3_auth_client`, and import `package:angel3_auth_client/angel3_auth_client.dart`. The classes keep their names.
- **The login cookie** is scoped to the path that the login route shares with the redirect URI, instead of the redirect URI's path, so mount the two routes under one path, such as `/auth/github` and `/auth/github/callback`. Logins in progress during the upgrade still complete: their cookies are still read, and the default `cookieKey` is the same. Behind a proxy that maps another path to the app's, give the browser's path as `cookiePath`.
- **`maxLogins`** (default 5): a browser may have that many logins in progress; starting or finishing one expires the cookies of the oldest beyond that. `maxLogins` must be at least 1, and `loginTimeout` at least a second, or the constructor throws an `ArgumentError`.
- **New options:** `authorizationParameters` adds query parameters to the authorization URL, and `basicAuth: false` sends the client secret in the form.
- **Errors given to `onError`:** a callback without a `code` is `invalid_request`, as is a posted callback whose body can't be read, with `response_mode=form_post`. A `state` that the strategy didn't give, as from a crafted link, is `invalid_state`. A provider that can't be reached, or whose token response can't be read, such as an error page, is a `502`, where it was `invalid_request`.
- **The verifier** may return `null` to refuse a user.
- **OpenID Connect:** `openId`, from `OpenIdOptions.discover`, checks the ID token of each login with a `nonce` of its own, and gives the verifier the `IdToken`.
- **A client without a secret** sends its `client_id` alone to the token endpoint, instead of an empty secret.

The [CHANGELOG](CHANGELOG.md) lists them all.
