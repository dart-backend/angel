import 'dart:collection';

import 'package:angel3_framework/angel3_framework.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

/// Calls [BASE64URL], but also works for strings with lengths
/// that are *not* multiples of 4.
///
/// Throws a [FormatException] if [str] is not base64url, or not UTF-8.
String decodeBase64(String str) {
  var output = str.replaceAll('-', '+').replaceAll('_', '/');

  switch (output.length % 4) {
    case 0:
      break;
    case 2:
      output += '==';
      break;
    case 3:
      output += '=';
      break;
    default:
      throw FormatException('Illegal base64url string.', str);
  }

  return utf8.decode(base64Url.decode(output));
}

/// Whether [a] and [b] are equal, in a time that does not depend on where
/// they differ, so that comparing a signature does not tell how much of it
/// is right.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

class AuthToken {
  static final _log = Logger('AuthToken');

  final SplayTreeMap<String, String> _header = SplayTreeMap.from({
    'alg': 'HS256',
    'typ': 'JWT',
  });

  String? ipAddress;

  /// How long the token is valid after [issuedAt], in milliseconds, or `-1`
  /// for ever.
  num lifeSpan;
  String userId;
  late DateTime issuedAt;
  Map<String, dynamic> payload = {};

  AuthToken({
    this.ipAddress,
    this.lifeSpan = -1,
    required this.userId,
    DateTime? issuedAt,
    Map<String, dynamic>? payload,
  }) {
    this.issuedAt = issuedAt ?? DateTime.now();
    if (payload != null) {
      this.payload.addAll({
        for (var MapEntry(:key, :value) in payload.entries)
          key.toString(): value,
      });
    }
  }

  /// When the token stops being valid, or `null` if it never does.
  DateTime? get expiresAt => lifeSpan > -1
      ? issuedAt.add(Duration(milliseconds: lifeSpan.toInt()))
      : null;

  /// Whether the token is no longer valid at [now] (default: now).
  bool isExpired([DateTime? now]) {
    var expiry = expiresAt;
    return expiry != null && !expiry.isAfter(now ?? DateTime.now());
  }

  factory AuthToken.fromJson(String jsons) =>
      AuthToken.fromMap(json.decode(jsons) as Map<String, dynamic>);

  /// Reads the claims of [toJson]: `iat` and `exp` in seconds since the
  /// epoch (NumericDate), as standard JWTs have them. Those of tokens issued
  /// before 10.0.0, an ISO 8601 `iat` and a lifespan in milliseconds as
  /// `exp`, are read too.
  ///
  /// Throws a [FormatException] for claims of the wrong types.
  factory AuthToken.fromMap(Map<String, dynamic> data) {
    var sub = data['sub'];
    if (sub is! String) throw FormatException('Missing `sub` claim.');
    var aud = data['aud'];
    var pld = data['pld'];
    var payload = pld is Map ? Map<String, dynamic>.from(pld) : null;

    var iat = data['iat'], exp = data['exp'];
    DateTime issuedAt;
    num lifeSpan;
    if (iat is String) {
      // Of a token issued before 10.0.0.
      issuedAt = DateTime.parse(iat);
      lifeSpan = exp is num ? exp : -1;
    } else if (iat is num) {
      issuedAt = DateTime.fromMillisecondsSinceEpoch((iat * 1000).round());
      lifeSpan = exp is num ? ((exp - iat) * 1000).round() : -1;
    } else {
      throw FormatException('Missing `iat` claim.');
    }

    return AuthToken(
      ipAddress: aud?.toString(),
      lifeSpan: lifeSpan,
      issuedAt: issuedAt,
      userId: sub,
      payload: payload,
    );
  }

  /// Reads a JWT without checking its signature; see [validate].
  ///
  /// Throws a 401 [AngelHttpException] if it is not a JWT of [toJson].
  factory AuthToken.parse(String jwt) {
    var split = jwt.split('.');

    if (split.length != 3) {
      _log.warning('Invalid JWT');
      throw AngelHttpException.notAuthenticated(message: 'Invalid JWT.');
    }

    return _read(split[1]);
  }

  /// Reads a JWT whose signature [hmac] makes.
  ///
  /// Throws a 401 [AngelHttpException] if it is not a JWT of [toJson], or its
  /// signature is not that of [hmac].
  factory AuthToken.validate(String jwt, Hmac hmac) {
    var split = jwt.split('.');

    if (split.length != 3) {
      _log.warning('Invalid JWT');
      throw AngelHttpException.notAuthenticated(message: 'Invalid JWT.');
    }

    var data = '${split[0]}.${split[1]}';
    var signature = base64Url.encode(hmac.convert(data.codeUnits).bytes);

    if (!_constantTimeEquals(signature, split[2])) {
      _log.warning('JWT payload does not match hashed version');
      throw AngelHttpException.notAuthenticated(
        message: 'JWT payload does not match hashed version.',
      );
    }

    return _read(split[1]);
  }

  /// The token of the base64url [payload] of a JWT.
  static AuthToken _read(String payload) {
    try {
      var data = json.decode(decodeBase64(payload));
      if (data is! Map<String, dynamic>) {
        throw FormatException('The payload is not an object.');
      }
      return AuthToken.fromMap(data);
    } on FormatException catch (e) {
      _log.warning('Invalid JWT: ${e.message}');
      throw AngelHttpException.notAuthenticated(message: 'Invalid JWT.');
    }
  }

  String serialize(Hmac hmac) {
    var headerString = base64Url.encode(json.encode(_header).codeUnits);
    var payloadString = base64Url.encode(utf8.encode(json.encode(toJson())));
    var data = '$headerString.$payloadString';
    var signature = hmac.convert(data.codeUnits).bytes;
    return '$data.${base64Url.encode(signature)}';
  }

  /// The claims of the token: `iat`, and `exp` if it expires, in seconds
  /// since the epoch, as standard JWTs have them.
  Map<String, dynamic> toJson() {
    var iat = issuedAt.millisecondsSinceEpoch / 1000;
    return _splayify({
      'iss': 'angel_auth',
      'aud': ipAddress,
      if (lifeSpan > -1) 'exp': iat + lifeSpan / 1000,
      'iat': iat,
      'sub': userId,
      'pld': _splayify(payload),
    });
  }
}

Map<String, dynamic> _splayify(Map<String, dynamic> map) {
  var data = {};
  map.forEach((k, v) {
    data[k] = _splay(v);
  });
  return SplayTreeMap.from(data);
}

dynamic _splay(dynamic value) {
  if (value is Iterable) {
    return value.map(_splay).toList();
  } else if (value is Map) {
    return _splayify(value as Map<String, dynamic>);
  } else {
    return value;
  }
}
