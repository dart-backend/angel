import 'dart:collection';
import 'package:angel3_framework/angel3_framework.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

/// Calls [BASE64URL], but also works for strings with lengths
/// that are *not* multiples of 4.
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
      throw 'Illegal base64url string!"';
  }

  return utf8.decode(base64Url.decode(output));
}

class AuthToken {
  static final _log = Logger('AuthToken');

  final SplayTreeMap<String, String> _header = SplayTreeMap.from({
    'alg': 'HS256',
    'typ': 'JWT',
  });

  String? ipAddress;
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
      this.payload.addAll(
        payload.keys.fold(
              {},
              ((out, k) => out?..[k.toString()] = payload[k]),
            ) ??
            {},
      );
    }
  }

  factory AuthToken.fromJson(String jsons) =>
      AuthToken.fromMap(json.decode(jsons) as Map<String, dynamic>);

  factory AuthToken.fromMap(Map<String, dynamic> data) {
    return AuthToken(
      ipAddress: data['aud'].toString(),
      lifeSpan: data['exp'] as num,
      issuedAt: DateTime.parse(data['iat'].toString()),
      userId: data['sub'],
      payload: data['pld'],
    );
  }

  factory AuthToken.parse(String jwt) {
    var split = jwt.split('.');

    if (split.length != 3) {
      _log.warning('Invalid JWT');
      throw AngelHttpException.notAuthenticated(message: 'Invalid JWT.');
    }

    var payloadString = decodeBase64(split[1]);
    return AuthToken.fromMap(
      json.decode(payloadString) as Map<String, dynamic>,
    );
  }

  factory AuthToken.validate(String jwt, Hmac hmac) {
    var split = jwt.split('.');

    if (split.length != 3) {
      _log.warning('Invalid JWT');
      throw AngelHttpException.notAuthenticated(message: 'Invalid JWT.');
    }

    // var headerString = decodeBase64(split[0]);
    var payloadString = decodeBase64(split[1]);
    var data = '${split[0]}.${split[1]}';
    var signature = base64Url.encode(hmac.convert(data.codeUnits).bytes);

    if (signature != split[2]) {
      _log.warning('JWT payload does not match hashed version');
      throw AngelHttpException.notAuthenticated(
        message: 'JWT payload does not match hashed version.',
      );
    }

    return AuthToken.fromMap(
      json.decode(payloadString) as Map<String, dynamic>,
    );
  }

  String serialize(Hmac hmac) {
    var headerString = base64Url.encode(json.encode(_header).codeUnits);
    var payloadString = base64Url.encode(json.encode(toJson()).codeUnits);
    var data = '$headerString.$payloadString';
    var signature = hmac.convert(data.codeUnits).bytes;
    return '$data.${base64Url.encode(signature)}';
  }

  Map<String, dynamic> toJson() {
    return _splayify({
      'iss': 'angel_auth',
      'aud': ipAddress,
      'exp': lifeSpan,
      'iat': issuedAt.toIso8601String(),
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
