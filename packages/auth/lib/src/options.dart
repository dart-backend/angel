import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'auth_token.dart';

typedef AngelAuthCallback =
    FutureOr Function(RequestContext req, ResponseContext res, String token);

typedef AngelAuthTokenCallback<User> =
    FutureOr Function(
      RequestContext req,
      ResponseContext res,
      AuthToken token,
      User user,
    );

class AngelAuthOptions<User> {
  AngelAuthCallback? callback;
  AngelAuthTokenCallback<User>? tokenCallback;
  String? successRedirect;
  String? failureRedirect;

  /// If `false` (default: `true`), then successful authentication will return `true` and allow the
  /// execution of subsequent handlers, just like any other middleware.
  ///
  /// Works well with `Basic` authentication.
  bool canRespondWithJson;

  AngelAuthOptions({
    this.callback,
    this.tokenCallback,
    this.canRespondWithJson = true,
    this.successRedirect,
    this.failureRedirect,
  });
}
