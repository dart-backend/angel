# Change Log

## 10.1.0

### New in 10.1.0

* **Documents:** `requireAuthentication` is tagged with a `SecurityRequirement` of `angel3_framework` 10.2.0, which this version requires, of a `Bearer` JWT and a 403, and `forceBasicAuth` with one of a `Bearer` JWT or Basic authentication and a 401, so that `angel3_openapi` documents the security of the routes they protect

## 10.0.2

### Fixes in 10.0.2

* **Docs:** The README is rewritten in plain English, with sections on trying several strategies, what a login answers, protecting routes and logging out. Its strategy list sample named a `basic` strategy that was never registered, and its popup sample used an undefined `authOptions`; both now work

## 10.0.1

### Breaking changes in 10.0.1

* **Breaking:** JWTs are issued with `"iss": "angel3_auth"`, where it was `"angel_auth"`. JWTs issued before are still accepted, as `iss` is not checked; update code of your own that checks it
* **Breaking:** The default realm of `forceBasicAuth` is `angel3_auth`, as documented, where it sent `angel_auth`; browsers that remembered Basic credentials for the old realm ask for them once more. Pass `realm: 'angel_auth'` to keep it

### Fixes in 10.0.1

* **Logout:** Once `logout` redirects to `successRedirect`, no handler after it runs
* **Local strategy:** Without valid credentials, of the form, it returns `null`, where it threw a 401 or redirected to `failureRedirect` itself, so that `authenticate` tries the next strategy of a list, as documented; of the last, `authenticate` answers the 401, or redirects to its `failureRedirect` with a 302, which browsers follow, where it was a 401. Invalid Basic credentials, and `forceBasic`, still answer a 401 with a Basic challenge
* **`authenticate`:** No strategy runs after one that has answered the request, which wrote to the closed response. The JSON answer of a login no longer serializes the user twice
* **`onLogin`:** Told of every new login once it is accepted, however it is answered, as by a redirect or a callback, where it was only of one answered with JSON; not of a login that `tokenCallback` refuses, nor of a user who is signed in already. With one `AngelAuth` configured on several apps, `onLogin` and `onLogout` close once the last of them shuts down, where the first one closed them for all; a login or logout after that, as of an instance configured again on a new app, is not an error, and the dropped event is warned about once
* **Basic authentication:** `forceBasicAuth` sends its `WWW-Authenticate: Basic` challenge, a 401, to a request of no JWT, where it was a 403 once `AngelAuth` was configured; a JWT that is not valid, as one that has expired, is still a 403
* **`requireAuthentication`:** Called with `throwError: false`, it returns `false` for a request of no JWT, where it threw a 403
* **`login` and `loginById`:** A user that does not exist is a 403, where it was logged in as `null`. `login` trusts its token, which the caller must have verified, as by `AuthToken.validate`. A request whose user is known already keeps that user; the new one is of the next request
* **`configureServer`:** Configuring an app again with the same instance does nothing, where it threw a `StateError`; another instance of the same user type still throws
* **`ExternalAuthOptions`:** `==` compares `clientSecret` and `redirectUri`, which it compared with themselves
* **Popup page:** `confirmPopupAuthentication` escapes `<` in its script, so an `eventName` of `</script>` cannot end it

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** `POST /auth/token` no longer revives expired JWTs, which made a stolen JWT valid for ever. It renews a valid one, or one expired within the new `reviveGracePeriod` (default: none), whose user still exists
* **Breaking:** `jwtLifeSpan` defaults to one day (`AngelAuth.defaultJwtLifeSpan`); `-1` (never expire) is warned about with a fixed `jwtKey`
* **Breaking:** The `token` cookie is `SameSite=Lax` (the new `cookieSameSite`), against CSRF, and is set only when a user logs in or a JWT is revived, not for `Bearer` requests
* **Breaking:** `allowTokenInQuery` defaults to `false`; enable it for the browser WebSocket client of `angel3_websocket`
* **Breaking:** JWTs have standard `iat` and `exp` claims, in seconds; JWTs issued before are still read

### Fixes in 10.0.0

* **Logout:** Expires the `token` cookie, instead of setting it to `""`
* **JWTs:** Signatures are compared in constant time, a malformed JWT is a 401 instead of a server error, and a JWT without an IP keeps none. `Bearer` is matched whole and in any case
* **Local strategy:** With `allowBasic`, form logins work too; a malformed Basic header is a 400, and credentials are read as UTF-8
* **Streams:** `onLogin` and `onLogout` are broadcast streams, so logins are not kept in memory, and both close on shutdown
* **`authenticate`:** Returns once a strategy has answered the request itself, instead of throwing 401
* **Key:** The default `jwtKey` is of random characters, not control characters
* **Tests:** No longer use `MirrorsReflector`; `AngelAuth` needs no reflection
* **Docs:** The README tells how to install and use the package, and how to migrate from 9.x


## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.4.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.1.1

* Updated repository link

## 8.1.0

* Updated `lints` to 3.0.0

## 8.0.0

* Require Dart >= 3.0
* Upgraded `http` to 1.0.0
* Fixed failed `successRedirect` test case
* Fixed failed `failureRedirect` test case
* Fixed failed `login` test case
* Fixed failed `force basic` test case
* Added `example1` and `example2`

## 7.0.1

* Fixed linter warnings

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.2

* Fixed `requireAuthentication` to work correctly with null-safety type

## 4.1.1

* Changed `userId` field of `AuthToken` to String type
* Changed `serializer` return value to String type
* Changed `deserializer` input parameter to String type

## 4.1.0

* Updated linter to `package:lints`

## 4.0.5

* Added support for verifier function to return an empty Map instead of null
* Fixed `canRespondWithJson` option to return data in the response body when set to true

## 4.0.4

* Changed `serializer` and `deserializer` parameters to be required
* Fixed HTTP basic authentication
* All 31 unit tests passed

## 4.0.3

* Fixed "failureRedirect" unit test

## 4.0.2

* Added MirrorsReflector to unit test

## 4.0.1

* Updated README

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.1.5+1

* Fix error in popup page.

## 2.1.5

* Modify `_apply` to honor an existing `User` over `Future<User>`.

## 2.1.4

* Deprecate `decodeJwt`, in favor of asynchronous injections.

## 2.1.3

* Use `await` on redirects, etc.

## 2.1.2

* Change empty cookie string to have double quotes (thanks @korsvanloon).

## 2.1.1

* Added `scopes` to `ExternalAuthOptions`.

## 2.1.0

* Added `ExternalAuthOptions`.

## 2.0.4

* `successRedirect` was previously explicitly returning a `200`; remove this and allow the default `302`.

## 2.0.3

* Updates for streaming parse of request bodies.

## 2.0.2

* Handle `null` return in `authenticate` + `failureRedirect`.

## 2.0.1

* Add generic parameter to `options` on `AuthStrategy.authenticate`.

## 2.0.0+1

* Meta update to improve Pub score.

## 2.0.0

* Made `AuthStrategy` generic.
* `AngelAuth.strategies` is now a `Map<String, AuthStrategy<User>>`.
* Removed `AuthStrategy.canLogout`.
* Made `AngelAuthTokenCallback` generic.

## 2.0.0-alpha

* Depend on Dart 2 and Angel 2.
* Remove `dart2_constant`.
* Remove `requireAuth`.
* Remove `userKey`, instead favoring generic parameters.

## 1.2.0

* Deprecate `requireAuth`, in favor of `requireAuthentication`.
* Allow configuring of the `userKey`.
* Deprecate `middlewareName`.

## 1.1.1+6

* Fix a small logic bug that prevented `LocalAuthStrategy`
from correctly propagating the authenticated user when
using `Basic` auth.

## 1.1.1+5

* Prevent duplication of cookies.
* Regenerate the JWT if `tokenCallback` is called.

## 1.1.1+4

* Patched `logout` to properly erase cookies
* Fixed checking of expired tokens.

## 1.1.1+3

* `authenticate` returns the current user, if one is present.

## 1.1.1+2

* `_apply` now always sends a `token` cookie.

## 1.1.1+1

* Update `protectCookie` to only send `maxAge` when it is not `-1`.

## 1.1.1

* Added `protectCookie`, to better protect data sent in cookies.

## 1.1.0+2

* `LocalAuthStrategy` returns `true` on `Basic` authentication.

## 1.1.0+1

* Modified `LocalAuthStrategy`'s handling of `Basic` authentication.
