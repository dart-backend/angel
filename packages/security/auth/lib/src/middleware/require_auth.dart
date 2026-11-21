import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';

import '../plugin.dart';

/// Forces Basic authentication over the requested resource, with the given [realm] name, if no JWT is present.
///
/// [realm] defaults to `'angel3_auth'`.
RequestHandler forceBasicAuth<User>({String? realm}) {
  return (RequestContext req, ResponseContext res) async {
    if (await _hasUser<User>(req)) return true;

    res.headers['www-authenticate'] = 'Basic realm="${realm ?? 'angel3_auth'}"';
    throw AngelHttpException.notAuthenticated();
  };
}

/// Restricts access to a resource via authentication.
RequestHandler requireAuthentication<User>() {
  return (
    RequestContext req,
    ResponseContext res, {
    bool throwError = true,
  }) async {
    bool reject(ResponseContext res) {
      if (throwError) {
        res.statusCode = 403;
        throw AngelHttpException.forbidden();
      } else {
        return false;
      }
    }

    if (req.method == 'OPTIONS' || await _hasUser<User>(req)) return true;
    return reject(res);
  };
}

/// Whether [req] has a [User]: `false` if it sent no JWT. A JWT that is
/// not valid, as one that has expired, throws its error, a 403.
///
/// The `Future<User>` of [AngelAuth] is registered in the container of the
/// app, so for every request, and throws without a JWT: whether one was
/// sent is asked of the [AngelAuth] first.
Future<bool> _hasUser<User>(RequestContext req) async {
  var container = req.container;
  if (container == null) return false;
  if (container.has<User>()) return true;
  if (!container.has<Future<User>>()) return false;
  if (container.has<AngelAuth<User>>() &&
      container.make<AngelAuth<User>>().getJwt(req) == null) {
    return false;
  }
  await container.makeAsync<User>();
  return true;
}
