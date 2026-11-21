import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:jose_plus/jose.dart';

/// The algorithms that an [OpenIdSigningKey] signs with: `RS256`, which
/// OpenID Connect requires every provider to support, and `ES256`.
const signingAlgorithms = {'RS256', 'ES256'};

/// The JWK members of a private key, which [OpenIdSigningKey.publicJwk]
/// leaves out.
const _privateMembers = {'d', 'p', 'q', 'dp', 'dq', 'qi', 'oth', 'k'};

/// A key that an OpenID provider signs its ID tokens with, of a key id
/// (`kid`), which its JSON Web Key Set publishes, so that clients pick the
/// key of each token.
///
/// `RS256` signatures are made with RSA blinding, as BoringSSL and OpenSSL
/// make them: the time a signature takes tells nothing of the key, as the
/// value exponentiated is random. Each is checked before it is given out, so
/// that a fault of the computation, which could leak a factor of the key,
/// gives no signature. `ES256` signatures are of `package:jose_plus`, whose
/// curve arithmetic is not constant-time: prefer `RS256` where timing
/// attacks against the server are a concern.
class OpenIdSigningKey {
  /// The key id, which the `kid` of each ID token it signs names.
  final String keyId;

  /// The algorithm of the key: `RS256` or `ES256`.
  final String algorithm;

  final JsonWebKey _jwk;
  final _RsaPrivateKey? _rsa;

  OpenIdSigningKey._(this.keyId, this.algorithm, this._jwk, this._rsa);

  /// A new random key of [algorithm], of [keyId]; an RSA key of
  /// [rsaBitLength] bits, of at least 2048 (RFC 7518 §3.3).
  ///
  /// Store its [toJson], as a secret, and load it with
  /// [OpenIdSigningKey.fromJwk], so that the tokens it signed stay valid
  /// across restarts, and so that every instance of the app signs alike.
  factory OpenIdSigningKey.generate({
    required String keyId,
    String algorithm = 'RS256',
    int rsaBitLength = 2048,
  }) {
    _checkAlgorithm(algorithm);
    var generated = JsonWebKey.generate(
      algorithm,
      keyBitLength: algorithm == 'RS256' ? rsaBitLength : null,
    );
    return OpenIdSigningKey.fromJwk({
      ...Map<String, dynamic>.from(generated.toJson() as Map),
      'kid': keyId,
      'alg': algorithm,
    });
  }

  /// The key of a private JSON Web Key (RFC 7517), as [toJson] gives, of a
  /// `kid`, and an `alg` of `RS256` or `ES256`. Throws an [ArgumentError] if
  /// it is not a private key of them, or an RSA key of under 2048 bits.
  factory OpenIdSigningKey.fromJwk(Map<String, dynamic> jwk) {
    var keyId = jwk['kid'], algorithm = jwk['alg'];
    if (keyId is! String || keyId.isEmpty) {
      throw ArgumentError.value(jwk['kid'], 'jwk', 'must have a "kid"');
    }
    if (algorithm is! String) {
      throw ArgumentError.value(jwk['alg'], 'jwk', 'must have an "alg"');
    }
    _checkAlgorithm(algorithm);
    var json = {
      for (var MapEntry(:key, :value) in jwk.entries)
        // Of signing alone.
        if (key != 'key_ops') key: value,
      'use': 'sig',
    };
    if (json['d'] == null) {
      throw ArgumentError.value(keyId, 'jwk', 'must be a private key');
    }
    var expected = algorithm == 'RS256' ? 'RSA' : 'EC';
    if (json['kty'] != expected) {
      throw ArgumentError.value(
        json['kty'],
        'jwk',
        'must be of "kty" "$expected", of "alg" "$algorithm"',
      );
    }
    if (algorithm == 'ES256' && json['crv'] != 'P-256') {
      throw ArgumentError.value(json['crv'], 'jwk', 'must be of P-256');
    }
    var rsa = algorithm == 'RS256' ? _RsaPrivateKey.fromJwk(json) : null;
    if (rsa != null && rsa.n.bitLength < 2048) {
      throw ArgumentError.value(
        '${rsa.n.bitLength} bits',
        'jwk',
        'must be an RSA key of at least 2048 bits',
      );
    }
    return OpenIdSigningKey._(
      keyId,
      algorithm,
      JsonWebKey.fromJson(json)!,
      rsa,
    );
  }

  static void _checkAlgorithm(String algorithm) {
    if (!signingAlgorithms.contains(algorithm)) {
      throw ArgumentError.value(
        algorithm,
        'algorithm',
        'must be one of ${signingAlgorithms.join(', ')}',
      );
    }
  }

  /// The private JSON Web Key of this key, to store, as a secret.
  Map<String, dynamic> toJson() =>
      Map<String, dynamic>.from(_jwk.toJson() as Map);

  /// The public JSON Web Key of this key, of no private member, which the
  /// JSON Web Key Set of the provider publishes.
  Map<String, dynamic> get publicJwk => {
    for (var MapEntry(:key, :value) in toJson().entries)
      if (!_privateMembers.contains(key)) key: value,
  };

  /// The signature of [data], in the form of a JWS (RFC 7515): of `RS256`,
  /// a blinded RSASSA-PKCS1-v1_5 signature; of `ES256`, the `r` and `s` of
  /// ECDSA on P-256.
  List<int> sign(List<int> data) =>
      _rsa?.signSha256(data) ?? _jwk.sign(data, algorithm: algorithm);

  /// [claims] as a compact JWS (RFC 7515 §7.1), of a header of [algorithm],
  /// [keyId] and the type `JWT`, signed by this key.
  String signJwt(Map<String, dynamic> claims) {
    var header = _base64Url(
      utf8.encode(json.encode({'alg': algorithm, 'kid': keyId, 'typ': 'JWT'})),
    );
    var payload = _base64Url(utf8.encode(json.encode(claims)));
    var signingInput = '$header.$payload';
    return '$signingInput.${_base64Url(sign(ascii.encode(signingInput)))}';
  }
}

/// [bytes] in base64url, of no padding, as JWS has them.
String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// A big-endian unsigned integer of a base64url JWK member (RFC 7518 §6.3).
BigInt _bigIntOf(Map<String, dynamic> jwk, String member) {
  var value = jwk[member];
  if (value is! String || value.isEmpty) {
    throw ArgumentError.value(member, 'jwk', 'must have "$member"');
  }
  return _os2ip(base64Url.decode(base64Url.normalize(value)));
}

/// The integer of [bytes], big-endian (RFC 8017 §4.2).
BigInt _os2ip(List<int> bytes) {
  var result = BigInt.zero;
  for (var byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

/// [value] as [length] big-endian bytes (RFC 8017 §4.1).
List<int> _i2osp(BigInt value, int length) {
  var bytes = List<int>.filled(length, 0);
  var mask = BigInt.from(0xff);
  for (var i = length - 1; i >= 0; i--) {
    bytes[i] = (value & mask).toInt();
    value >>= 8;
  }
  return bytes;
}

/// The DER prefix of the `DigestInfo` of SHA-256 (RFC 8017 §9.2, note 1).
const _sha256DigestInfo = [
  0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, //
  0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
];

/// An RSA private key, which signs RSASSA-PKCS1-v1_5 with SHA-256 (RFC 8017
/// §8.2.1), blinded, and checked.
class _RsaPrivateKey {
  final BigInt n, e, d;

  /// The factors of [n], and the CRT values of them (RFC 8017 §3.2), if the
  /// key has its factors.
  final BigInt? p, q, dp, dq, qi;

  final Random _random = Random.secure();

  _RsaPrivateKey(this.n, this.e, this.d, this.p, this.q)
    : dp = p == null ? null : d % (p - BigInt.one),
      dq = q == null ? null : d % (q - BigInt.one),
      qi = p == null || q == null ? null : q.modInverse(p);

  factory _RsaPrivateKey.fromJwk(Map<String, dynamic> jwk) {
    var n = _bigIntOf(jwk, 'n'), e = _bigIntOf(jwk, 'e');
    var d = _bigIntOf(jwk, 'd');
    // Of both factors, or of neither, of which `d` alone signs.
    var hasFactors = jwk['p'] != null && jwk['q'] != null;
    var p = hasFactors ? _bigIntOf(jwk, 'p') : null;
    var q = hasFactors ? _bigIntOf(jwk, 'q') : null;
    if (p != null && q != null && p * q != n) {
      throw ArgumentError.value('p, q', 'jwk', 'must be the factors of "n"');
    }
    return _RsaPrivateKey(n, e, d, p, q);
  }

  /// The length of [n] in bytes.
  int get _length => (n.bitLength + 7) ~/ 8;

  /// The RSASSA-PKCS1-v1_5 signature of [data], of SHA-256.
  List<int> signSha256(List<int> data) {
    var k = _length;
    var t = [..._sha256DigestInfo, ...sha256.convert(data).bytes];
    // EM = 0x00 || 0x01 || PS || 0x00 || T (RFC 8017 §9.2), of a PS of at
    // least 8 bytes of 0xff.
    var em = [0x00, 0x01, ...List.filled(k - t.length - 3, 0xff), 0x00, ...t];
    var m = _os2ip(em);

    // Blinded: of m·rᵉ, whose exponentiation is of a value of a random r,
    // then of its result × r⁻¹, which is mᵈ.
    var r = _blindingFactor();
    var blinded = (m * r.modPow(e, n)) % n;
    var s = (_privateExponentiation(blinded) * r.modInverse(n)) % n;

    // Of a fault of the computation, which of CRT could leak a factor of n:
    // a signature that does not verify is not given out.
    if (s.modPow(e, n) != m) {
      throw StateError('An RSA signature did not verify, and was withheld.');
    }
    return _i2osp(s, k);
  }

  /// cᵈ mod n, of the CRT values if the key has its factors.
  BigInt _privateExponentiation(BigInt c) {
    if (p == null || q == null) return c.modPow(d, n);
    var m1 = c.modPow(dp!, p!), m2 = c.modPow(dq!, q!);
    var h = (qi! * (m1 - m2)) % p!;
    return m2 + h * q!;
  }

  /// A random r of 1 < r < n, coprime to n.
  BigInt _blindingFactor() {
    while (true) {
      // Of 8 bytes more than n, so that r mod n is all but uniform.
      var bytes = [for (var i = 0; i < _length + 8; i++) _random.nextInt(256)];
      var r = _os2ip(bytes) % n;
      if (r > BigInt.one && r.gcd(n) == BigInt.one) return r;
    }
  }
}
