import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:jose_plus/jose.dart';

/// The signing algorithms of ID tokens that [OpenIdOptions] may accept: those
/// of public keys, of which a client cannot forge a token, as of `HS256` it
/// could of its own secret, nor `none`.
const openIdAlgorithms = {
  'RS256',
  'RS384',
  'RS512',
  'PS256',
  'PS384',
  'PS512',
  'ES256',
  'ES384',
  'ES512',
};

/// The hosts of an `http` issuer, of a provider of the developer's machine.
const _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

/// How an `OAuth2Strategy` checks the ID tokens of an OpenID Provider
/// (OpenID Connect Core 1.0 §3.1.3.7): of its [issuer], and of its JSON Web
/// Key Set at [jwksUri], of which their signatures are checked.
///
/// The strategy then sends a `nonce` of each login, which the ID token must
/// give back, and gives the verifier the [IdToken], in `req.container`, once
/// it is checked. Of [OpenIdOptions.discover], of the configuration of the
/// provider.
class OpenIdOptions {
  /// The issuer of the provider, which the `iss` of each ID token must be.
  final Uri issuer;

  /// The URL of the provider's JSON Web Key Set.
  final Uri jwksUri;

  /// The algorithms of the ID tokens that are accepted, of
  /// [openIdAlgorithms]. Default: `RS256`, which every provider supports,
  /// and `ES256`.
  final Set<String> algorithms;

  /// How far the clocks of the app and the provider may differ, of which an
  /// ID token is accepted a little after it expires, or issued a little
  /// ahead. Default: 2 minutes.
  final Duration clockSkew;

  /// How long the keys of the JSON Web Key Set are kept, before they are
  /// fetched again. A token of a key that is not among them fetches them
  /// again at once, as when the provider rotates its keys; of such tokens,
  /// at most once a minute. Default: an hour.
  final Duration keysLifetime;

  OpenIdOptions({
    required this.issuer,
    required this.jwksUri,
    this.algorithms = const {'RS256', 'ES256'},
    this.clockSkew = const Duration(minutes: 2),
    this.keysLifetime = const Duration(hours: 1),
  }) {
    _checkIssuer(issuer);
    if (algorithms.isEmpty || !openIdAlgorithms.containsAll(algorithms)) {
      throw ArgumentError.value(
        algorithms,
        'algorithms',
        'must be of ${openIdAlgorithms.join(', ')}',
      );
    }
    if (clockSkew.isNegative) {
      throw ArgumentError.value(clockSkew, 'clockSkew', 'must not be negative');
    }
  }

  static void _checkIssuer(Uri issuer) {
    if (issuer.hasQuery || issuer.hasFragment) {
      throw ArgumentError.value(
        issuer,
        'issuer',
        'must have no query nor fragment',
      );
    }
    if (!issuer.isScheme('https') &&
        !(issuer.isScheme('http') && _loopbackHosts.contains(issuer.host))) {
      throw ArgumentError.value(
        issuer,
        'issuer',
        'must be https, or http of localhost',
      );
    }
  }

  /// The configuration of the OpenID Provider of [issuer] (OpenID Connect
  /// Discovery 1.0 §4), of its endpoints and the [OpenIdOptions] of its
  /// keys, of [httpClient] if given.
  ///
  /// Throws a [FormatException] if the configuration is not of [issuer],
  /// exactly, as Discovery §4.3 requires, or has no endpoints of the code
  /// flow, or no JSON Web Key Set.
  static Future<OpenIdProvider> discover(
    Uri issuer, {
    http.Client? httpClient,
    Duration clockSkew = const Duration(minutes: 2),
  }) async {
    _checkIssuer(issuer);
    var path = issuer.path.endsWith('/')
        ? issuer.path.substring(0, issuer.path.length - 1)
        : issuer.path;
    var configuration = issuer.replace(
      path: '$path/.well-known/openid-configuration',
    );
    var client = httpClient ?? http.Client();
    try {
      var response = await client.get(configuration);
      if (response.statusCode != 200) {
        throw FormatException(
          'The configuration of $issuer is a ${response.statusCode}.',
        );
      }
      var config = json.decode(response.body);
      if (config is! Map) {
        throw FormatException('The configuration of $issuer is not an object.');
      }
      if (config['issuer'] != issuer.toString()) {
        throw FormatException(
          'The configuration of $issuer is of the issuer ${config['issuer']}.',
        );
      }
      Uri url(String name) {
        var value = config[name];
        var uri = value is String ? Uri.tryParse(value) : null;
        if (uri == null || !uri.isAbsolute) {
          throw FormatException('The configuration of $issuer has no "$name".');
        }
        return uri;
      }

      var supported = config['id_token_signing_alg_values_supported'];
      var algorithms = {
        if (supported is List)
          for (var alg in supported)
            if (openIdAlgorithms.contains(alg)) alg as String,
      };
      return OpenIdProvider(
        authorizationEndpoint: url('authorization_endpoint'),
        tokenEndpoint: url('token_endpoint'),
        userInfoEndpoint: config['userinfo_endpoint'] is String
            ? url('userinfo_endpoint')
            : null,
        endSessionEndpoint: config['end_session_endpoint'] is String
            ? url('end_session_endpoint')
            : null,
        openId: OpenIdOptions(
          issuer: issuer,
          jwksUri: url('jwks_uri'),
          // Of RS256, which every provider supports, of none listed.
          algorithms: algorithms.isEmpty ? const {'RS256'} : algorithms,
          clockSkew: clockSkew,
        ),
      );
    } finally {
      if (httpClient == null) client.close();
    }
  }
}

/// The configuration of an OpenID Provider, of [OpenIdOptions.discover]:
/// the endpoints to give an `OAuth2Strategy`, and its [openId].
class OpenIdProvider {
  final Uri authorizationEndpoint, tokenEndpoint;
  final Uri? userInfoEndpoint;

  /// The endpoint at which the provider signs its user out (OpenID Connect
  /// RP-Initiated Logout 1.0), if it has one, of [endSessionUrl].
  final Uri? endSessionEndpoint;

  final OpenIdOptions openId;

  OpenIdProvider({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.userInfoEndpoint,
    this.endSessionEndpoint,
    required this.openId,
  });

  /// The URL to redirect a user to, to sign them out of the provider too,
  /// once the app has signed them out of itself (OpenID Connect
  /// RP-Initiated Logout 1.0 §2): of [idTokenHint], the [IdToken.token] of
  /// their login, which the provider then needs not ask them about; of
  /// [postLogoutRedirectUri], which must be one the app registered with the
  /// provider, to which it redirects them after, with [state]; and of
  /// [clientId], of none of [idTokenHint].
  ///
  /// Throws a [StateError] if the provider has no [endSessionEndpoint].
  Uri endSessionUrl({
    String? idTokenHint,
    Uri? postLogoutRedirectUri,
    String? state,
    String? clientId,
  }) {
    var endpoint = endSessionEndpoint;
    if (endpoint == null) {
      throw StateError('The provider has no end session endpoint.');
    }
    return endpoint.replace(
      queryParameters: {
        ...endpoint.queryParametersAll,
        'id_token_hint': ?idTokenHint,
        'post_logout_redirect_uri': ?postLogoutRedirectUri?.toString(),
        'state': ?state,
        'client_id': ?clientId,
      },
    );
  }
}

/// An ID token that an `OAuth2Strategy` checked: of its provider's key, of
/// its issuer, of the app as its audience, of the `nonce` of its login, and
/// that has not expired. The verifier is given it in `req.container`:
///
/// ```dart
/// var idToken = req.container!.make<IdToken>();
/// var user = await findOrCreateUser(idToken.issuer, idToken.subject);
/// ```
///
/// Know a user by their [issuer] and [subject] together, which are unique
/// and never change: not by their `email`, which may.
class IdToken {
  /// The ID token, as the provider signed it.
  final String token;

  /// The claims of the token.
  final Map<String, dynamic> claims;

  IdToken(this.token, this.claims);

  /// The `iss` of the token.
  String get issuer => claims['iss'] as String;

  /// The `sub` of the token: the user, at its [issuer].
  String get subject => claims['sub'] as String;

  /// The `aud` of the token, of the `client_id` of the app.
  List<String> get audience => switch (claims['aud']) {
    String aud => [aud],
    List aud => aud.cast<String>(),
    _ => const [],
  };

  /// When the token expires.
  DateTime get expiresAt => _time(claims['exp'])!;

  /// When the token was issued.
  DateTime get issuedAt => _time(claims['iat'])!;

  /// When the user authenticated, if the provider said.
  DateTime? get authTime => _time(claims['auth_time']);

  /// The `nonce` of the token, which was that of its login.
  String? get nonce => claims['nonce'] as String?;

  static DateTime? _time(Object? seconds) => seconds is num
      ? DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round())
      : null;
}

/// An ID token that is refused, of [message].
class IdTokenException implements Exception {
  final String message;
  IdTokenException(this.message);

  @override
  String toString() => 'IdTokenException: $message';
}

/// Checks the ID tokens of [options] (OpenID Connect Core 1.0 §3.1.3.7), of
/// the keys of its JSON Web Key Set, fetched by [client].
class IdTokenVerifier {
  final OpenIdOptions options;
  final http.Client client;

  /// How long a fetch of the keys may take.
  final Duration timeout;

  JsonWebKeySet? _keys;
  DateTime? _fetched;

  /// When the keys were last fetched again of a token of an unknown key,
  /// which is at most once a minute, so that tokens of made-up key ids
  /// cannot make the app fetch them for each.
  DateTime? _refreshed;

  IdTokenVerifier(this.options, this.client, {required this.timeout});

  /// The keys of the JSON Web Key Set, fetched again if they are older than
  /// [OpenIdOptions.keysLifetime], or if [refresh].
  Future<JsonWebKeySet> _keySet({bool refresh = false}) async {
    var now = DateTime.now();
    var keys = _keys, fetched = _fetched;
    if (keys != null &&
        fetched != null &&
        !refresh &&
        now.difference(fetched) < options.keysLifetime) {
      return keys;
    }
    var response = await client.get(options.jwksUri).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'The JSON Web Key Set is a ${response.statusCode}.',
        options.jwksUri,
      );
    }
    var set = JsonWebKeySet.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
    _keys = set;
    _fetched = now;
    return set;
  }

  /// The claims of [token], of its signature, of a key of [_keySet].
  Future<Map<String, dynamic>> _verifiedClaims(String token) async {
    JsonWebSignature jws;
    try {
      jws = JsonWebSignature.fromCompactSerialization(token);
    } catch (_) {
      throw IdTokenException('The ID token is not a JWS.');
    }
    var header = jws.commonProtectedHeader;
    var algorithm = header.algorithm;
    if (algorithm == null || !options.algorithms.contains(algorithm)) {
      throw IdTokenException(
        'The ID token is of the algorithm "$algorithm", which is not '
        'accepted.',
      );
    }

    Future<Map<String, dynamic>?> tryKeys(JsonWebKeySet keys) async {
      var store = JsonWebKeyStore()..addKeySet(keys);
      try {
        var payload = await jws.getPayload(
          store,
          allowedAlgorithms: options.algorithms.toList(),
        );
        var claims = payload.jsonContent;
        if (claims is! Map<String, dynamic>) {
          throw IdTokenException(
            'The claims of the ID token are not an object.',
          );
        }
        return claims;
      } on IdTokenException {
        rethrow;
      } catch (_) {
        return null;
      }
    }

    var keys = await _keySet();
    var claims = await tryKeys(keys);
    if (claims != null) return claims;
    // Of a key that is not among them, as of keys the provider rotated: of
    // them fetched again, at most once a minute.
    var keyId = header.keyId;
    var known = keys.keys.any((key) => key.keyId == keyId);
    var refreshed = _refreshed;
    if (!known &&
        (refreshed == null ||
            DateTime.now().difference(refreshed) >
                const Duration(minutes: 1))) {
      _refreshed = DateTime.now();
      claims = await tryKeys(await _keySet(refresh: true));
      if (claims != null) return claims;
    }
    throw IdTokenException(
      'The signature of the ID token is not of a key of the provider.',
    );
  }

  /// The [IdToken] of [token], once checked: of [clientId] as its audience,
  /// of [nonce], and of the `at_hash` of [accessToken], if it has one.
  /// Throws an [IdTokenException] of a token that is refused.
  Future<IdToken> verify(
    String token, {
    required String clientId,
    required String nonce,
    String? accessToken,
    DateTime? now,
  }) async {
    var claims = await _verifiedClaims(token);
    var time = now ?? DateTime.now();

    if (claims['iss'] != options.issuer.toString()) {
      throw IdTokenException(
        'The ID token is of the issuer ${claims['iss']}, not '
        '${options.issuer}.',
      );
    }
    var sub = claims['sub'];
    if (sub is! String || sub.isEmpty) {
      throw IdTokenException('The ID token has no "sub".');
    }

    var aud = claims['aud'];
    var audience = aud is String
        ? [aud]
        : aud is List && aud.every((v) => v is String)
        ? aud.cast<String>()
        : null;
    if (audience == null || !audience.contains(clientId)) {
      throw IdTokenException('The ID token is not of this app as audience.');
    }
    // Of several audiences, of this app as the party it was issued to.
    var azp = claims['azp'];
    if ((audience.length > 1 || azp != null) && azp != clientId) {
      throw IdTokenException(
        'The ID token was issued to ${azp ?? 'no "azp"'}, not this app.',
      );
    }

    DateTime? at(String name) {
      var value = claims[name];
      return value is num
          ? DateTime.fromMillisecondsSinceEpoch((value * 1000).round())
          : null;
    }

    var exp = at('exp'), iat = at('iat');
    if (exp == null || iat == null) {
      throw IdTokenException('The ID token has no "exp" or "iat".');
    }
    if (!time.isBefore(exp.add(options.clockSkew))) {
      throw IdTokenException('The ID token has expired.');
    }
    if (iat.isAfter(time.add(options.clockSkew))) {
      throw IdTokenException('The ID token was issued ahead of now.');
    }

    if (claims['nonce'] != nonce) {
      throw IdTokenException(
        'The "nonce" of the ID token is not of its login.',
      );
    }

    if (claims['at_hash'] case var atHash? when accessToken != null) {
      var algorithm = JsonWebSignature.fromCompactSerialization(token)
          .commonProtectedHeader
          .algorithm!;
      if (atHash != _halfHash(accessToken, algorithm)) {
        throw IdTokenException(
          'The "at_hash" of the ID token is not of its access token.',
        );
      }
    }
    return IdToken(token, claims);
  }

  /// The left half of the hash of [value] of the hash of [algorithm], in
  /// base64url (OpenID Connect Core 1.0 §3.1.3.6).
  static String _halfHash(String value, String algorithm) {
    var hash = switch (algorithm.substring(2)) {
      '384' => sha384,
      '512' => sha512,
      _ => sha256,
    };
    var digest = hash.convert(ascii.encode(value)).bytes;
    return base64Url
        .encode(digest.sublist(0, digest.length ~/ 2))
        .replaceAll('=', '');
  }
}
