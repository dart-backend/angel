import 'dart:convert';

import 'package:angel3_oidc_server/angel3_oidc_server.dart';
import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

/// Whether [jwt] verifies of the public [jwk] alone, as a client verifies.
Future<bool> verifies(String jwt, Map<String, dynamic> jwk) async {
  var store = JsonWebKeyStore()..addKey(JsonWebKey.fromJson(jwk)!);
  return JsonWebSignature.fromCompactSerialization(jwt).verify(store);
}

void main() {
  late OpenIdSigningKey rsa, ec;

  setUpAll(() {
    rsa = OpenIdSigningKey.generate(keyId: 'rsa-1');
    ec = OpenIdSigningKey.generate(keyId: 'ec-1', algorithm: 'ES256');
  });

  group('RS256', () {
    test('is the signature of RSASSA-PKCS1-v1_5, as jose_plus signs, '
        'blinded or not', () {
      var data = utf8.encode('header.payload');
      var unblinded = JsonWebKey.fromJson(rsa.toJson())!
          .sign(data, algorithm: 'RS256');
      // Deterministic: of any blinding factor, the same signature.
      expect(rsa.sign(data), unblinded);
      expect(rsa.sign(data), unblinded);
    });

    test('signs of d alone, of a key of no factors', () {
      var json = rsa.toJson()..removeWhere((k, _) => k == 'p' || k == 'q');
      var data = utf8.encode('x');
      expect(OpenIdSigningKey.fromJwk(json).sign(data), rsa.sign(data));
    });

    test('a JWT of it verifies of its public JWK', () async {
      var jwt = rsa.signJwt({'sub': 'alice'});
      expect(await verifies(jwt, rsa.publicJwk), isTrue);
      var header = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[0]))),
      );
      expect(header, {'alg': 'RS256', 'kid': 'rsa-1', 'typ': 'JWT'});
    });

    test('a key of a d of another, whose signatures do not verify, is '
        'refused as it loads', () {
      // A d that is not of e: each signature fails the check after it,
      // which loading the key runs.
      var json = rsa.toJson()..['d'] = rsa.toJson()['e'];
      expect(() => OpenIdSigningKey.fromJwk(json), throwsArgumentError);
      // Of its factors alone, of no d of CRT: refused alike.
      var noFactors = rsa.toJson()
        ..['d'] = rsa.toJson()['e']
        ..remove('p')
        ..remove('q');
      expect(() => OpenIdSigningKey.fromJwk(noFactors), throwsArgumentError);
    });
  });

  test('ES256: a key of a d of another is refused as it loads', () {
    var another = OpenIdSigningKey.generate(keyId: 'x', algorithm: 'ES256');
    var json = ec.toJson()..['d'] = another.toJson()['d'];
    expect(() => OpenIdSigningKey.fromJwk(json), throwsArgumentError);
  });

  test('ES256: a JWT of it verifies of its public JWK', () async {
    var jwt = ec.signJwt({'sub': 'alice'});
    expect(await verifies(jwt, ec.publicJwk), isTrue);
    expect(jwt.split('.')[2], hasLength(86)); // 64 bytes: r and s.
  });

  test('a JWT does not verify of another key', () async {
    var other = OpenIdSigningKey.generate(keyId: 'ec-2', algorithm: 'ES256');
    expect(await verifies(other.signJwt({'sub': 'x'}), ec.publicJwk), isFalse);
  });

  test('the public JWK is of no private member', () {
    for (var key in [rsa, ec]) {
      var jwk = key.publicJwk;
      for (var member in ['d', 'p', 'q', 'dp', 'dq', 'qi']) {
        expect(jwk, isNot(contains(member)));
      }
      expect(jwk, containsPair('kid', key.keyId));
      expect(jwk, containsPair('alg', key.algorithm));
      expect(jwk, containsPair('use', 'sig'));
    }
  });

  test('toJson loads back as the same key', () {
    var loaded = OpenIdSigningKey.fromJwk(rsa.toJson());
    expect(loaded.sign([1]), rsa.sign([1]));
    expect(loaded.keyId, 'rsa-1');
  });

  group('fromJwk refuses', () {
    test('a key of no kid, or of another algorithm', () {
      expect(
        () => OpenIdSigningKey.fromJwk(rsa.toJson()..remove('kid')),
        throwsArgumentError,
      );
      expect(
        () => OpenIdSigningKey.fromJwk(rsa.toJson()..['alg'] = 'HS256'),
        throwsArgumentError,
      );
      expect(
        () => OpenIdSigningKey.fromJwk(ec.toJson()..['alg'] = 'RS256'),
        throwsArgumentError,
      );
    });

    test('a public key', () {
      expect(
        () => OpenIdSigningKey.fromJwk(rsa.publicJwk),
        throwsArgumentError,
      );
    });

    test('an RSA key of under 2048 bits', () {
      // Of 1024 bits, which jose_plus refuses to generate; of no factors,
      // as the size is checked before the key signs.
      String b64(List<int> bytes) =>
          base64Url.encode(bytes).replaceAll('=', '');
      expect(
        () => OpenIdSigningKey.fromJwk({
          'kty': 'RSA',
          'kid': 'small',
          'alg': 'RS256',
          'n': b64([0x80, ...List.filled(127, 0x01)]),
          'e': 'AQAB',
          'd': b64([0x02]),
        }),
        throwsArgumentError,
      );
    });

    test('factors that are not of n', () {
      var json = rsa.toJson()..['p'] = rsa.toJson()['q'];
      expect(() => OpenIdSigningKey.fromJwk(json), throwsArgumentError);
    });
  });
}
