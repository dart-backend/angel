import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:angel3_framework/angel3_framework.dart';
import '../options.dart';
import '../strategy.dart';

/// Determines the validity of an incoming username and password.
// typedef FutureOr<User> LocalAuthVerifier<User>(String? username, String? password);
typedef LocalAuthVerifier<User> = FutureOr<User?> Function(
    String? username, String? password);

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

  LocalAuthStrategy(this.verifier,
      {this.usernameField = 'username',
      this.passwordField = 'password',
      this.invalidMessage = 'Please provide a valid username and password.',
      this.allowBasic = true,
      this.forceBasic = false,
      this.realm = 'Authentication is required.'}) {
    _log.info('Using LocalAuthStrategy');
  }

  @override
  Future<User?> authenticate(RequestContext req, ResponseContext res,
      [AngelAuthOptions? options]) async {
    var localOptions = options ?? AngelAuthOptions();
    User? verificationResult;

    if (allowBasic) {
      var authHeader = req.headers?.value('authorization') ?? '';

      if (_rgxBasic.hasMatch(authHeader)) {
        var base64AuthString = _rgxBasic.firstMatch(authHeader)?.group(1);
        if (base64AuthString == null) {
          return null;
        }
        var authString = String.fromCharCodes(base64.decode(base64AuthString));
        if (_rgxUsrPass.hasMatch(authString)) {
          Match usrPassMatch = _rgxUsrPass.firstMatch(authString)!;
          verificationResult =
              await verifier(usrPassMatch.group(1), usrPassMatch.group(2));
        } else {
          _log.warning('Bad request: $invalidMessage');
          throw AngelHttpException.badRequest(errors: [invalidMessage]);
        }

        if (verificationResult == null) {
          res
            ..statusCode = 401
            ..headers['www-authenticate'] = 'Basic realm="$realm"';
          await res.close();
          return null;
        }

        // Allow non-null to pass through
        //return verificationResult;
      }
    }

    if (verificationResult is Map && verificationResult.isEmpty) {
      if (localOptions.failureRedirect != null &&
          localOptions.failureRedirect!.isNotEmpty) {
        await res.redirect(localOptions.failureRedirect, code: 401);
        return null;
      }

      if (forceBasic) {
        res.headers['www-authenticate'] = 'Basic realm="$realm"';
        return null;
      }

      return null;
    } else if (verificationResult != false ||
        (verificationResult is Map && verificationResult.isNotEmpty)) {
      return verificationResult;
    } else {
      _log.info('Not authenticated');
      throw AngelHttpException.notAuthenticated();
    }
  }
}
