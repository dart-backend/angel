import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'exception.dart';

/// A class that facilitates verification of challenges for
/// [Proof Key for Code Exchange](https://oauth.net/2/pkce/).
class Pkce {
  /// A [String] defining how to handle the [codeChallenge]: `plain` or
  /// `S256` (RFC 7636), or `s256`, which earlier versions required.
  final String codeChallengeMethod;

  /// The proof key that is used to secure public clients.
  final String? codeChallenge;

  Pkce(this.codeChallengeMethod, this.codeChallenge) {
    assert(
      _isMethod(codeChallengeMethod),
      "The `code_challenge_method` parameter must be either 'plain' or 'S256'.",
    );
  }

  /// Attempts to parse a [codeChallenge] and [codeChallengeMethod] from a [Map].
  factory Pkce.fromJson(Map data, {String? state, Uri? uri}) {
    var codeChallenge = data['code_challenge']?.toString();
    var codeChallengeMethod =
        data['code_challenge_method']?.toString() ?? 'plain';

    if (!_isMethod(codeChallengeMethod)) {
      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.invalidRequest,
          "The `code_challenge_method` parameter must be either 'plain' or 'S256'.",
          state,
          uri: uri,
        ),
      );
    } else if (codeChallenge?.isNotEmpty != true) {
      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.invalidRequest,
          'Missing `code_challenge` parameter.',
          state,
          uri: uri,
        ),
      );
    }

    return Pkce(codeChallengeMethod, codeChallenge);
  }

  /// Returns [true] if the [codeChallengeMethod] is `plain`.
  bool get isPlain => codeChallengeMethod == 'plain';

  /// Returns [true] if the [codeChallengeMethod] is `S256` (or `s256`).
  bool get isS256 =>
      codeChallengeMethod == 'S256' || codeChallengeMethod == 's256';

  static bool _isMethod(String method) =>
      method == 'plain' || method == 'S256' || method == 's256';

  /// Determines if a given [codeVerifier] is valid.
  void validate(String codeVerifier, {String? state, Uri? uri}) {
    String foreignChallenge, challenge = codeChallenge ?? '';

    if (isS256) {
      // BASE64URL without padding (RFC 7636); a padded challenge, which
      // earlier versions required, is accepted too.
      foreignChallenge = base64Url
          .encode(sha256.convert(ascii.encode(codeVerifier)).bytes)
          .replaceAll('=', '');
      challenge = challenge.replaceAll('=', '');
    } else {
      foreignChallenge = codeVerifier;
    }

    if (!_equalsInConstantTime(foreignChallenge, challenge)) {
      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.invalidGrant,
          'The given `code_verifier` parameter is invalid.',
          state,
          uri: uri,
        ),
      );
    }
  }

  /// Creates a JSON-serializable representation of this instance.
  Map<String, dynamic> toJson() {
    return {
      'code_challenge': codeChallenge,
      'code_challenge_method': codeChallengeMethod,
    };
  }
}

/// Compares [a] and [b] in a time that does not depend on where they differ,
/// so that a verifier cannot be guessed one character at a time.
bool _equalsInConstantTime(String a, String b) {
  var diff = a.length ^ b.length;
  for (var i = 0; i < a.length && i < b.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
