# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Renamed from `angel3_oauth2`: depend on `angel3_oauth2_server`, and import `package:angel3_oauth2_server/angel3_oauth2_server.dart`
* **Breaking:** A client that cannot be authenticated at the token endpoint, of no or a malformed `Authorization` header, an unknown id or a wrong secret, is `invalid_client`, a 401, as RFC 6749 requires, where it was `unauthorized_client`, a 400; with `WWW-Authenticate: Basic realm="oauth2"` if it used the `Authorization` header, or gave no credentials. So is an unknown `client_id` of a device code request or grant
* **Breaking:** A grant type that the server does not support, unknown or not implemented, is `unsupported_grant_type`, where it was `invalid_request` or `unsupported_response_type`, as is a device code request that it does not implement. An unknown grant type is refused before the client is authenticated

### New in 10.0.0

* **Client authentication:** Without an `Authorization` header, a client is authenticated by the `client_id` and `client_secret` of the form of its request to the token endpoint (RFC 6749 §2.3.1); a public client, as of PKCE, gives its `client_id` alone, and `verifyClient` is given a `null` secret

### Fixes in 10.0.0

* **Scopes:** The password and refresh token grants read `scope` from the form of the request, where they read the query and got none. Scopes are separated by any spaces, and empty ones are dropped
* **Authorization code:** The default `exchangeAuthorizationCodeForToken` reads `state` from the form, as the other grants do
* **PKCE:** `code_challenge_method=S256`, as RFC 7636 spells it, is accepted, and an S256 challenge is compared without its `=` padding, so standard clients are no longer refused with `invalid_grant`; `s256` and padded challenges still work. The challenge is compared in constant time. A `code_verifier` of non-ASCII characters is compared with the challenge, as UTF-8, where it was a 500
* **Client authentication:** The `Basic` header is decoded as UTF-8, where non-ASCII credentials were garbled, and a malformed one is `invalid_client` instead of a 500. A client secret may have a `$`, which cut it short. Only a header of the `Basic` scheme is read, of any case, and its base64 may be unpadded. The client id and secret are percent-decoded, as clients encode them (RFC 6749 §2.3.1), where a secret of a space or a non-ASCII character was refused; a `+` is kept, as `package:oauth2` does not encode it
* **Authorization endpoint:** An unknown `client_id` is `unauthorized_client`, where it was a 500
* **Example:** `example1.dart` starts a server, without importing from `test/`
* **Dependencies:** Removed the unused `angel3_container` and `angel3_validate`
* **Tests:** The tests and example no longer use `MirrorsReflector`; `AuthorizationServer` needs no reflection

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
* Fixed linter warnings

## 8.0.0

* Require Dart >= 3.0
* Updated to `uuid`

## 7.0.0

* Require Dart >= 2.17

## 6.0.1

* Fixed AngelHttpException error
* [Breaking] Renamed `error` to `authError` for `AuthorizationException`

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.1

* Updated README

## 4.1.0

* Updated linter to `package:lints`

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD

## 3.0.0

* Migrated to work with Dart >= 2.12 Non NNBD

## 2.3.0

* Remove `implicitGrant`, and inline it into `requestAuthorizationCode`.

## 2.2.0+1

* Parse+verify client for `authorization_code`.

## 2.2.0

* Pass `client` to `exchangeAuthorizationCodeForToken`.
* Apply `package:pedantic`.

## 2.1.0

* Updates
* Support `device_code` grants.
* Add support for [PKCE](https://tools.ietf.org/html/rfc7636).

## 2.0.0

* Angel 2 support.

## 1.0.0+1

* Dart2 updates + backwards compatibility assurance.
