import 'dart:async';

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_oauth2/angel3_oauth2.dart';
import 'package:logging/logging.dart';

import '../test/common.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
      '${record.time} ${record.level.name.padLeft(6, ' ')} [${record.loggerName}] : ${record.message}',
    );
    if (record.error != null) print(record.error);
    if (record.stackTrace != null) print(record.stackTrace);
  });

  // Declae the function
  void setUp() async {
    var app = Angel(reflector: MirrorsReflector());
    var oauth2 = _AuthorizationServer();

    app.group('/oauth2', (router) {
      router
        ..get('/authorize', oauth2.authorizationEndpoint)
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
      res.json(e.toJson());
    };
  }

  setUp();
}

class _AuthorizationServer
    extends AuthorizationServer<PseudoApplication, PseudoUser> {
  var logger = Logger('AuthorizationServer');

  @override
  PseudoApplication? findClient(String? clientId) {
    return clientId == pseudoApplication.id ? pseudoApplication : null;
  }

  @override
  Future<bool> verifyClient(
    PseudoApplication client,
    String? clientSecret,
  ) async {
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
      Uri.parse(
        'https://regiostech.com',
      ).replace(queryParameters: {'scopes': scopes.join(',')}),
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
