import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:angel3_framework/angel3_framework.dart';

import '../options.dart';
import '../strategy.dart';

/// Determines the validity of an incoming username and password.
// typedef FutureOr<User> LocalAuthVerifier<User>(String? username, String? password);
typedef LocalAuthVerifier<User> = FutureOr<User?> Function(
  String? username,
  String? password,
);

class LocalAuthStrategy<User> extends AuthStrategy<User> {
  final _log = Logger('LocalAuthStrategy');

  final RegExp _rgxBasic = RegExp(r'^Basic (.+)$', caseSensitive: false);
  final RegExp _rgxUsrPass = RegExp(r'^([^:]+):(.+)$');

  LocalAuthVerifier<User> verifier;
  String usernameField;
  String passwordField;
  String invalidMessage;
  final bool allowBasic;
  final bool forceBasic;
  String realm;

  LocalAuthStrategy(
    this.verifier, {
    this.usernameField = 'username',
    this.passwordField = 'password',
    this.invalidMessage = 'Please provide a valid username and password.',
    this.allowBasic = false,
    this.forceBasic = false,
    this.realm = 'Authentication is required.',
  }) {
    _log.info('Using LocalAuthStrategy');
  }

  @override
  Future<User?> authenticate(
    RequestContext req,
    ResponseContext res, [
    AngelAuthOptions? options,
  ]) async {
    var localOptions = options ?? AngelAuthOptions();
    User? verificationResult;

    // Basic, if allowed and sent; the fields of the body otherwise.
    var basic = allowBasic
        ? _rgxBasic.firstMatch(req.headers?.value('authorization') ?? '')
        : null;

    if (basic != null) {
      var (username, password) = _basicCredentials(basic.group(1)!);
      verificationResult = await verifier(username, password);

      if (verificationResult == null) {
        res
          ..statusCode = 401
          ..headers['www-authenticate'] = 'Basic realm="$realm"';
        await res.close();
        return null;
      }
    } else {
      var body = await req
          .parseBody()
          .then((_) => req.bodyAsMap)
          .catchError((_) => <String, dynamic>{});
      if (_validateString(body[usernameField]?.toString()) &&
          _validateString(body[passwordField]?.toString())) {
        verificationResult = await verifier(
          body[usernameField]?.toString(),
          body[passwordField]?.toString(),
        );
      }
    }

    // User authentication succeeded can return Map(one element), User(non null) or true
    if (verificationResult != null && verificationResult != false) {
      if (verificationResult is Map && verificationResult.isNotEmpty) {
        return verificationResult;
      } else if (verificationResult is! Map) {
        return verificationResult;
      }
    }

    // Force basic if set
    if (forceBasic) {
      res
        ..statusCode = 401
        ..headers['www-authenticate'] = 'Basic realm="$realm"';
      await res.close();
      return null;
    }

    // Redirect failed authentication
    if (localOptions.failureRedirect != null &&
        localOptions.failureRedirect!.isNotEmpty) {
      await res.redirect(localOptions.failureRedirect, code: 401);
      return null;
    }

    _log.info('Not authenticated');
    throw AngelHttpException.notAuthenticated();
  }

  /// The username and password of the base64 [credentials] of a Basic
  /// `Authorization` header, as UTF-8 (RFC 7617), or else Latin-1. Throws a
  /// 400 if they are not base64, or have no `:`.
  (String, String) _basicCredentials(String credentials) {
    List<int> bytes;
    try {
      bytes = base64.decode(credentials.trim());
    } on FormatException {
      _log.warning('Bad request: $invalidMessage');
      throw AngelHttpException.badRequest(errors: [invalidMessage]);
    }
    String decoded;
    try {
      decoded = utf8.decode(bytes);
    } on FormatException {
      decoded = latin1.decode(bytes);
    }
    var match = _rgxUsrPass.firstMatch(decoded);
    if (match == null) {
      _log.warning('Bad request: $invalidMessage');
      throw AngelHttpException.badRequest(errors: [invalidMessage]);
    }
    return (match.group(1)!, match.group(2)!);
  }

  bool _validateString(String? str) => str != null && str.isNotEmpty;
}
