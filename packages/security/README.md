# Angel3 Security

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_security?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/security/LICENSE)

Angel3 middleware designed to enhance application security by patching common Web security holes.

## CSRF protection

`CsrfFilter` refuses cross-site requests that change state (all but `GET`, `HEAD`, `OPTIONS` and `TRACE`) with a `403`. Such a request must:

* come from an allowed origin: `Sec-Fetch-Site: same-origin`, or else an `Origin` (or `Referer`) in `allowedOrigins`;
* send back the token, which is the value of the `XSRF-TOKEN` cookie, in the `X-XSRF-TOKEN` header (as axios and Angular do) or the `_csrf` form field.

The cookie is signed with a `CookieSigner` and bound to the session, so another site can neither forge it nor read it. A form shown before its session expired is refused; the next page gets a new token.

```dart
var signer = CookieSigner.fromStringKey(keyFromConfiguration);
var csrf = CsrfFilter(signer, allowedOrigins: {'https://example.com'});
app.fallback(csrf.handleRequest);

app.get('/form', (req, res) {
  // The token of the request, for a hidden `_csrf` field.
  var token = req.container!.make<CsrfToken>().value;
  // ...
});
```

Requests that do not use cookies to authenticate, such as those with a bearer token, can be exempted with `skip`. See `example/csrf.dart`.
