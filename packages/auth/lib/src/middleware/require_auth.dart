import 'dart:async';
import 'package:angel3_framework/angel3_framework.dart';

/// Forces Basic authentication over the requested resource, with the given [realm] name, if no JWT is present.
///
/// [realm] defaults to `'angel_auth'`.
RequestHandler forceBasicAuth<User>({String? realm}) {
  return (RequestContext req, ResponseContext res) async {
    if (req.container != null) {
      var reqContainer = req.container!;
      if (reqContainer.has<User>()) {
        return true;
      } else if (reqContainer.has<Future<User>>()) {
        await reqContainer.makeAsync<User>();
        return true;
      }
    }

    res.headers['www-authenticate'] = 'Basic realm="${realm ?? 'angel_auth'}"';
    throw AngelHttpException.notAuthenticated();
  };
}

/// Restricts access to a resource via authentication.
RequestHandler requireAuthentication<User>() {
  return (RequestContext req, ResponseContext res,
      {bool throwError = true}) async {
    bool _reject(ResponseContext res) {
      if (throwError) {
        res.statusCode = 403;
        throw AngelHttpException.forbidden();
      } else {
        return false;
      }
    }

    if (req.container != null) {
      var reqContainer = req.container!;
      if (reqContainer.has<User>() || req.method == 'OPTIONS') {
        return true;
      } else if (reqContainer.has<Future<User>>()) {
        await reqContainer.makeAsync<User>();
        return true;
      } else {
        return _reject(res);
      }
    } else {
      return _reject(res);
    }
  };
}
