# Change Log

## 8.3.0

* Require Dart >= 3.5
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
