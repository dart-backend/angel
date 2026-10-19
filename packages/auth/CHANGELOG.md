# Change Log

## 10.0.0-beta.1

* **Breaking:** `POST /auth/token` (`reviveTokenEndpoint`) no longer revives an expired JWT, which it did for ever by resetting its `iat`, so a JWT stolen once never expired. It exchanges a JWT that is still valid, or expired by no more than the new `reviveGracePeriod` (default: none), for a new one of the configured `jwtLifeSpan`, and refuses one whose user no longer exists
* **Breaking:** `jwtLifeSpan` defaults to one day (`AngelAuth.defaultJwtLifeSpan`), where JWTs never expired. `-1` keeps them valid for ever, which is warned about with a fixed `jwtKey`
* **Breaking:** The `token` cookie is `SameSite=Lax` by default (the new `cookieSameSite`), so other sites' requests do not carry it (CSRF). It is set when a user logs in or a JWT is revived, no longer for every request authenticated with an `Authorization: Bearer` header
* **Breaking:** `allowTokenInQuery` defaults to `false`: a JWT in the query string, which ends up in logs, history and `Referer` headers, is ignored unless enabled. Enable it for the browser WebSocket client of `angel3_websocket`, which sends its JWT as `?token=`
* **Breaking:** JWTs have standard `iat` and `exp` claims, in seconds since the epoch, where `iat` was an ISO 8601 string and `exp` the lifespan in milliseconds; those issued before are still read
* fix: `logout` expires the `token` cookie, where it set it to `""`, which every later request sent as an invalid JWT. An empty `token` cookie or query parameter is no JWT
* fix: `onLogin` and `onLogout` are broadcast streams, where every login and logout was kept in memory until someone listened; both are closed on shutdown
* fix: A JWT's signature is compared in constant time. A malformed JWT (not base64url, not JSON, or without its claims) is a `401`, where it was a server error, and a JWT without an IP address keeps none, where its `aud` was read as `"null"`
* fix: `LocalAuthStrategy(allowBasic: true)` also reads the username and password of the body when no Basic header is sent, where it read only the header. A malformed Basic header is a `400`, where it was a server error, and its credentials are read as UTF-8 (RFC 7617)
* fix: The `Bearer` scheme is matched whole and without regard to case. The default `jwtKey` is of random characters, where it was of control characters
* test: `security_test.dart`
* test: The tests and examples no longer use `MirrorsReflector`, and the `angel3_container_mirrors` dev dependency is removed; `AngelAuth` does not need reflection
* chore: Released with the other Angel3 packages at 10.0.0

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
