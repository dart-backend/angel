import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_oauth2_server/angel3_oauth2_server.dart';
import 'package:logging/logging.dart';

/// Serves the device code flow on http://localhost:3000/oauth2.
///
/// A device, a public client, gives its `client_id` alone:
///
/// ```sh
/// curl -d client_id=device http://localhost:3000/oauth2/device
/// curl -d grant_type=urn:ietf:params:oauth:grant-type:device_code \
///   -d client_id=device -d device_code=foo http://localhost:3000/oauth2/token
/// ```
Future<void> main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
      '${record.time} ${record.level.name.padLeft(6, ' ')} [${record.loggerName}] : ${record.message}',
    );
    if (record.error != null) print(record.error);
    if (record.stackTrace != null) print(record.stackTrace);
  });

  var app = Angel();
  var oauth2 = _AuthorizationServer();

  app.group('/oauth2', (router) {
    router
      ..get('/authorize', oauth2.authorizationEndpoint)
      ..post('/device', oauth2.deviceAuthorizationEndpoint)
      ..post('/token', oauth2.tokenEndpoint);
  });

  //app.logger.level = Level.ALL;
  app.logger = Logger("oauth2")
    ..onRecord.listen((rec) {
      print(rec);
      if (rec.error != null) print(rec.error);
      if (rec.stackTrace != null) print(rec.stackTrace);
    });

  app.errorHandler = (e, req, res) async {
    // Of the status of the error, such as 400, or 401 of `invalid_client`
    // (RFC 6749 §5.2).
    res.statusCode = e.statusCode;
    res.json(e.toJson());
  };

  var http = AngelHttp(app);
  await http.startServer('localhost', 3000);
  print('Listening at ${http.uri}');
}

class _AuthorizationServer
    extends AuthorizationServer<PseudoApplication, PseudoUser> {
  var logger = Logger('AuthorizationServer');

  @override
  PseudoApplication? findClient(String? clientId) {
    return [
      pseudoApplication,
      deviceApplication,
    ].where((client) => client.id == clientId).firstOrNull;
  }

  @override
  Future<bool> verifyClient(
    PseudoApplication client,
    String? clientSecret,
  ) async {
    // A public client, stored without a secret, gives none: `null`.
    if (client.secret.isEmpty) return clientSecret == null;
    return client.secret == clientSecret;
  }

  @override
  FutureOr<DeviceCodeResponse> requestDeviceCode(
    PseudoApplication client,
    Iterable<String> scopes,
    RequestContext req,
    ResponseContext res,
  ) {
    return DeviceCodeResponse(
      'foo',
      'bar',
      Uri.parse('https://regiostech.com')
          .replace(queryParameters: {'scopes': scopes.join(',')}),
      3600,
    );
  }

  @override
  FutureOr<AuthorizationTokenResponse> exchangeDeviceCodeForToken(
    PseudoApplication client,
    String? deviceCode,
    String state,
    RequestContext req,
    ResponseContext res,
  ) {
    print("[Server] exchangeDeviceCodeForToken");
    print("[Server] $deviceCode");
    print("[Server] $client");

    if (deviceCode == 'brute') {
      print("[Server] Throws AuthorizationException");

      throw AuthorizationException(
        ErrorResponse(
          ErrorResponse.slowDown,
          'Ho, brother! Ho, whoa, whoa, whoa now! You got too much dip on your chip!',
          state,
        ),
      );
    }

    return AuthorizationTokenResponse('foo');
  }
}

const PseudoApplication pseudoApplication = PseudoApplication(
  'foo',
  'bar',
  'http://foo.bar/baz',
);

/// A public client, of a device, without a secret.
const PseudoApplication deviceApplication = PseudoApplication(
  'device',
  '',
  'http://foo.bar/baz',
);

class PseudoApplication {
  final String id, secret, redirectUri;

  const PseudoApplication(this.id, this.secret, this.redirectUri);
}

const List<PseudoUser> pseudoUsers = [
  PseudoUser(username: 'foo', password: 'bar'),
  PseudoUser(username: 'michael', password: 'jackson'),
  PseudoUser(username: 'jon', password: 'skeet'),
];

class PseudoUser {
  final String? username, password;

  const PseudoUser({this.username, this.password});
}
