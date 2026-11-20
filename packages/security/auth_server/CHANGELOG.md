# Change Log

## 10.0.0

### Breaking changes in 10.0.0

* **Breaking:** Renamed from `angel3_oauth2`: depend on `angel3_auth_server`, and import `package:angel3_auth_server/angel3_auth_server.dart`
* **Breaking:** A client that cannot be authenticated at the token endpoint, of no credentials, a malformed `Authorization: Basic` header, an unknown id or a wrong secret, is `invalid_client`, a 401, as RFC 6749 requires, where it was `unauthorized_client`, a 400; with `WWW-Authenticate: Basic realm="oauth2"` if it used the `Authorization` header, or gave no credentials. So is an unknown `client_id` of a device code request or grant
* **Breaking:** A grant type that the server does not support, unknown or not implemented, is `unsupported_grant_type`, where it was `invalid_request` or `unsupported_response_type`. An unknown grant type is refused before the client is authenticated; a known one that the server does not implement is refused once the request is well-formed, so one without its `code`, `code_verifier` or `username` is still `invalid_request`
* **Breaking:** A device code request is no longer taken at the token endpoint, without a `grant_type`: route a `deviceAuthorizationEndpoint` (RFC 8628 §3.1), and point device clients at it. A request to the token endpoint without a `grant_type`, or with an empty `grant_type=`, is `invalid_request`, before the client is authenticated. Without `requestDeviceCode`, a device authorization request is `unsupported_grant_type`, where it was `invalid_request`
* **Breaking:** An empty client secret, of `Basic id:` or `client_secret=`, is given to `verifyClient` as `null`, as no secret is, where it was `''`: a `verifyClient` that compares it with a stored `''` must accept `null`
* **Breaking:** A device code request or grant authenticates its client as the other grants do, where its `client_id` was only looked up, and its secret ignored: a confidential client must give its secret, by an `Authorization: Basic` header, with or without a `client_id`, or by `client_secret`, or it is `invalid_client`. A public client gives its `client_id` alone, and `verifyClient` is given a `null` secret, for which it must return `true` for that client. A request without a `client_id` or a header is `invalid_client`, where it was `invalid_request`
* **Breaking:** A `client_id` or `client_secret` in the form of a request with an `Authorization: Basic` header must be that of the header, or it is `invalid_request`, where it was ignored; once the header's credentials are verified, so that wrong ones are still `invalid_client`
* **Breaking:** The `scope` of a token response is a string of space-separated scopes, as RFC 6749 requires, where it was a JSON list, which clients such as `package:oauth2` refused
* **Breaking:** The token request of an authorization code grant may leave out its `redirect_uri` (RFC 6749 §4.1.3): `exchangeAuthorizationCodeForToken` is given `null`, and must check it against the one stored with the code, which the token request must then give
* **Breaking:** At the authorization endpoint, the client is found before the `response_type` is read, and an unknown `response_type` is `unsupported_response_type`, where it was `invalid_request`; a missing one is still `invalid_request`. An unknown `client_id` is `invalid_request`, where it was a 500
* **Breaking:** `clientCredentialsGrant` is given the `scopes` of the request (RFC 6749 §4.4.2), as the password and refresh token grants are: add `Iterable<String> scopes` after its `client` parameter
* **Breaking:** An authorization code grant must use PKCE with `S256` (RFC 7636), as OAuth 2.1 and RFC 9700 have it: its authorization request must give a `code_challenge` and `code_challenge_method=S256`, where none, or `plain`, was accepted, and its token request a `code_verifier`, of 43 to 128 characters, and the challenge of 43, the base64url of a SHA-256 hash, or it is `invalid_request`. Override `requiresPkce` to return `false` for clients that cannot use PKCE, and `allowsPlainPkce` to return `true` to accept `plain`. `exchangeAuthorizationCodeForToken` must still compare the verifier with the stored challenge, by `Pkce.validate`
* **Breaking:** The implicit grant, of `response_type=token`, is refused by default, as `unsupported_response_type`, as OAuth 2.1 and RFC 9700 have it, where every request was given to `requestAuthorizationCode`. Override the new `allowsImplicitGrant` to return `true` for clients that still use it
* **Breaking:** The token endpoint no longer injects a `Pkce` into the request's container: one of the token request, which has a `code_verifier` and no challenge, failed for honest clients, and passed for one that sent a `code_challenge` of its own with its verifier. Build the `Pkce` of the challenge stored with the code, as the README shows
* **Breaking:** The client id and secret of the `Authorization: Basic` header are percent-decoded, as clients encode them (RFC 6749 §2.3.1): a secret of a valid `%XX`, such as `a%20b`, sent unencoded, as 9.x matched it, is now `a b`, and refused. Encode such a secret, as `package:oauth2` does; a `%` that is not of a valid `%XX` is still kept

### New in 10.0.0

* **Client authentication:** Without an `Authorization` header, a client is authenticated by the `client_id` and `client_secret` of the form of its request to the token endpoint (RFC 6749 §2.3.1); a public client, as of PKCE, gives its `client_id` alone, and `verifyClient` is given a `null` secret. A client authenticated without a secret may not use the client credentials grant, which is for confidential clients (RFC 6749 §4.4): it is `unauthorized_client`, a 400

* **Redirect URIs:** `registeredRedirectUri` checks the `redirect_uri` of an authorization request against those registered for the client. Once it returns one, the request may leave out its `redirect_uri`, and its errors are redirected to it, with their `error`, `error_description` and `state`, after its query, which is kept as it is (RFC 6749 §3.1.2), or in the fragment of an implicit grant (RFC 6749 §4.1.2.1, §4.2.2.1). By default, it returns `null`, and the endpoint behaves as before. An unexpected error, of no `AuthorizationException`, is redirected as `server_error`, and logged
* **Authorization endpoint:** It reads its parameters from the form of a POST, as from the query of a GET (RFC 6749 §3.1); route both to it. `completeAuthorizationCode` gives the redirect URI of an authorization code, with its `code` and `state` after its query, which is kept as it is, as `completeImplicitGrant` does of a token

* **Device authorization:** `deviceAuthorizationEndpoint` handles device authorization requests at an endpoint of their own, as RFC 8628 §3.1 has them, which standard device clients use: route a POST to it. It authenticates the client as the token endpoint does, and gives the `DeviceCodeResponse` of `requestDeviceCode`, with `Cache-Control: no-store`, or, without `requestDeviceCode`, `unsupported_grant_type`

* **Protecting resources:** `requireToken` protects the handlers after it with the access tokens of the server (RFC 6750): it reads the `Authorization: Bearer` header, or, if allowed, the `access_token` of a form, finds the token by `findAccessToken`, which gives an `AccessToken` of its client, user, scopes and expiry, and refuses a request without a token, or of an unknown, expired or malformed one, or of one without the scopes required, with the `WWW-Authenticate: Bearer` challenge and error of RFC 6750 §3 (`invalid_token`, `insufficient_scope`, `invalid_request`). The handlers after it get the `AccessToken` from `req.container`. `ErrorResponse` adds `invalidToken` and `insufficientScope`

* **Token revocation:** `revocationEndpoint` revokes a token of a client, as when its user logs out (RFC 7009): it authenticates the client as the token endpoint does, gives the `token` and its `token_type_hint` to `revokeToken`, and answers a 200 without a body, whether the token was revoked or not; without `revokeToken`, it is `unsupported_token_type`, which `ErrorResponse` adds as `unsupportedTokenType`

* **Server metadata:** `metadataEndpoint` serves the metadata of the server (RFC 8414), from which clients find its endpoints: `ServerMetadata` gives its issuer, the URLs of its endpoints and the grants it implements, and the server adds its device code and extension grants, `implicit` of the `token` response type, and its PKCE methods; `wellKnownPath` is the path to route it at, and `metadataOf` gives it as a `Map`

* **Token introspection:** `introspectionEndpoint` tells a resource server whether a token is active, and of what (RFC 7662): its caller must authenticate as a client with a secret, which `mayIntrospect` allows, as no client is by default; it finds the token by `introspectToken`, which is `findAccessToken` by default, and answers `{"active": false}` for one that is unknown, revoked or expired, or else its `scope`, `exp` and `iat`, and what `introspectionClaims` gives the caller, which may also make it inactive to it. `AccessToken` adds `issuedAt`, and `ServerMetadata` an `introspectionEndpoint`

* **Client registration:** `registrationEndpoint` lets a client register itself (RFC 7591), if `mayRegisterClient` accepts its initial access token: it checks its metadata against the `ServerMetadata` of the server, as its grant, response types, client authentication methods, scopes and redirect URIs; a client of the `token` response type alone registers the `implicit` grant type by default; the redirect URIs must be `https`, `http` of loopback, or of a reverse domain name scheme of a native app, such as `com.example.app:` (RFC 8252 §7.1), issues it an id, and a secret unless it is public, and gives the `ClientRegistration` to `registerClient` to store, and answers a 201 of it, or `invalid_client_metadata` or `invalid_redirect_uri`, which `ErrorResponse` adds. `registerClient` may change other metadata, such as a `client_name`; the response gives the checked metadata, such as `grant_types`, of the fields of the `ClientRegistration`, which are what is stored. `ServerMetadata` adds a `registrationEndpoint`, and `ClientRegistration` a `copyWith`
* **Registration management:** If `managesClientRegistrations`, a client that registers itself is also issued a `registration_access_token` and its `registration_client_uri`, at which `registrationManagementEndpoint` lets it read, update and delete its registration (RFC 7592): it finds the registration by `findRegistration`, of the token, which is `invalid_token` for a client that does not exist too; a PUT replaces all its metadata, as a registration is checked, of its `client_id` and its `client_secret`, if given, and is stored by `updateClient`, which may be given a new secret and token, of `rotatesClientSecretOnUpdate` and `rotatesRegistrationAccessToken`; a GET and a PUT give the token (RFC 7592 §3); a DELETE is given to `deleteClient`, a 204. `updateClient` and `deleteClient` refuse by default. An empty `client_secret` of a PUT is none, as at the token endpoint

### Fixes in 10.0.0

* **Implicit grant:** `completeImplicitGrant` gives no `state` of a request without one, where it gave an empty `state=` (RFC 6749 §4.2.2), and form-encodes its fragment, as its error redirects are, a space as `+` (RFC 6749 Appendix B)
* **PKCE verifier:** `getPkceCodeVerifier` throws `invalid_request` of an empty `code_verifier=`, as of a missing one, where it gave `''`
* **Client credentials:** A refresh token is left out of the JSON of the response, where the response was rebuilt without it, and lost what a subclass of `AuthorizationTokenResponse` adds
* **Token responses:** The responses of the token endpoint have `Cache-Control: no-store` and `Pragma: no-cache`, as RFC 6749 §5.1 requires, so that tokens are not cached

* **Scopes:** The password and refresh token grants read `scope` from the form of the request, where they read the query and got none. Scopes are separated by any spaces, and empty ones are dropped
* **Authorization code:** The default `exchangeAuthorizationCodeForToken` reads `state` from the form, as the other grants do
* **PKCE:** `code_challenge_method=S256`, as RFC 7636 spells it, is accepted, and an S256 challenge is compared without its `=` padding, so standard clients are no longer refused with `invalid_grant`; `s256` and padded challenges still work. The challenge is compared in constant time. A `code_verifier` of non-ASCII characters is compared with the challenge, as UTF-8, where it was a 500
* **Client authentication:** The `Basic` header is decoded as UTF-8, where non-ASCII credentials were garbled, and a malformed one, or one of an empty client id, is `invalid_client` instead of a 500. A client secret may have a `$`, which cut it short. Only an `Authorization` header of the `Basic` scheme is read, of any case, with leading spaces or not, and its base64 may be unpadded; one of another scheme, as of a proxy, is ignored, beside a Basic one or alone, where several headers were a 500, and the client is authenticated by the form; so are headers joined by commas in one value, as `HttpClient` and the shelf driver join them. Two Basic headers are `invalid_request`. A secret of a space or a non-ASCII character, which clients percent-encode, is accepted, where it was refused; a `+` is kept, as `package:oauth2` does not encode it, and so are escapes that are not valid UTF-8, such as `%FF`, where they were a 500. An unknown client and a wrong secret are refused with one `error_description`, so that a guess of a secret does not confirm the client id; ids are not secret (RFC 6749 §2.2), and the authorization endpoint names an unknown one
* **Example:** `example1.dart` starts a server, without importing from `test/`, and answers an error of its status code, where it was a 200
* **Dependencies:** Removed the unused `angel3_container` and `angel3_validate`, and moved `collection`, which only the tests use, to `dev_dependencies`
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
