import 'dart:convert';

import 'package:angel3_oauth2/angel3_oauth2.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  const verifier = 'dBjftJeZ4CVP-mJ92K23Ul_ycL7Eupkym5c2hrtYQdHsS0';
  var padded = base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes);
  var unpadded = padded.replaceAll('=', '');

  test('S256 accepts the unpadded challenge of RFC 7636', () {
    var pkce = Pkce.fromJson({
      'code_challenge': unpadded,
      'code_challenge_method': 'S256',
    });
    expect(pkce.isS256, isTrue);
    pkce.validate(verifier);
  });

  test('a padded challenge and s256 are still accepted', () {
    Pkce('s256', padded).validate(verifier);
    Pkce('S256', padded).validate(verifier);
  });

  test('a wrong verifier is refused', () {
    expect(
      () => Pkce('S256', unpadded).validate('${verifier}x'),
      throwsA(isA<AuthorizationException>()),
    );
    expect(
      () => Pkce('plain', 'foo').validate('fo'),
      throwsA(isA<AuthorizationException>()),
    );
  });

  test('an unknown method is refused', () {
    expect(
      () => Pkce.fromJson({
        'code_challenge': 'x',
        'code_challenge_method': 'S512',
      }),
      throwsA(isA<AuthorizationException>()),
    );
  });
}
