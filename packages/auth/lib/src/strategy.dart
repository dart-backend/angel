import 'dart:async';
import 'package:angel3_framework/angel3_framework.dart';
import 'options.dart';

/// A function that handles login and signup for an Angel application.
abstract class AuthStrategy<User> {
  /// Authenticates or rejects an incoming user.
  FutureOr<User?> authenticate(
    RequestContext req,
    ResponseContext res, [
    AngelAuthOptions<User>? options,
  ]);
}
