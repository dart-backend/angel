import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:angel3_oauth2_server/angel3_oauth2_server.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  late TestClient client;

  setUp(() async {
    var app = Angel();
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

    client = await connectTo(app);
  });

  tearDown(() => client.close());

  group('get initial code', () {
    test('invalid client id', () async {
      var response = await client.post(
        Uri.parse('/oauth2/token'),
        body: {'client_id': 'barr'},
      );
      print(response.body);
      expect(response, hasStatus(401));
      expect(response.body, contains('invalid_client'));
    });

    test('valid client id, no scopes', () async {
      var response = await client.post(
        Uri.parse('/oauth2/token'),
        body: {'client_id': 'device'},
      );
      print(response.body);
      expect(
        response,
        allOf(
          hasStatus(200),
          isJson({
            'device_code': 'foo',
            'user_code': 'bar',
            'verification_uri': 'https://regiostech.com?scopes',
            'expires_in': 3600,
          }),
        ),
      );
    });

    test('valid client id, with scopes', () async {
      var response = await client.post(
        Uri.parse('/oauth2/token'),
        body: {'client_id': 'device', 'scope': 'bar baz quux'},
      );
      print(response.body);
      expect(
        response,
        allOf(
          hasStatus(200),
          isJson({
            'device_code': 'foo',
            'user_code': 'bar',
            'verification_uri': Uri.parse('https://regiostech.com')
                .replace(queryParameters: {'scopes': 'bar,baz,quux'})
                .toString(),
            'expires_in': 3600,
          }),
        ),
      );
    });
  });

  group('get token', () {
    test('valid device code + timing', () async {
      var response = await client.post(
        Uri.parse('/oauth2/token'),
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': 'device',
          'device_code': 'bar',
        },
      );

      print(response.body);
      expect(
        response,
        allOf(
          hasStatus(200),
          isJson({'token_type': 'bearer', 'access_token': 'foo'}),
        ),
      );
    });

    Future<http.Response> exchange(
      Map<String, String> body, {
      Map<String, String>? headers,
    }) => client.post(
      Uri.parse('/oauth2/token'),
      headers: headers,
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        'device_code': 'bar',
        ...body,
      },
    );

    test('a client that gives a secret is authenticated', () async {
      expect(
        await exchange({'client_id': 'foo', 'client_secret': 'bar'}),
        hasStatus(200),
      );
      var response = await exchange({
        'client_id': 'foo',
        'client_secret': 'wrong',
      });
      expect(response, hasStatus(401));
      expect(response.body, contains('invalid_client'));
    });

    test('a confidential client must give its secret', () async {
      for (var body in [
        {'client_id': 'foo'},
        {'client_id': 'foo', 'client_secret': ''},
      ]) {
        var response = await exchange(body);
        expect(response, hasStatus(401));
        expect(response.body, contains('invalid_client'));
        var request = await client.post(Uri.parse('/oauth2/token'), body: body);
        expect(request, hasStatus(401));
      }
    });

    test('a client_id of the form must be of the Basic header', () async {
      var basic = 'Basic ${base64.encode('foo:bar'.codeUnits)}';
      var response = await exchange(
        {'client_id': 'device'},
        headers: {'Authorization': basic},
      );
      expect(response, hasStatus(400));
      expect(response.body, contains('invalid_request'));
      expect(
        await exchange({'client_id': 'foo'}, headers: {'Authorization': basic}),
        hasStatus(200),
      );
    });

    test('the header is verified before the form is compared', () async {
      var wrong = 'Basic ${base64.encode('foo:wrong'.codeUnits)}';
      var response = await exchange(
        {'client_id': 'device'},
        headers: {'Authorization': wrong},
      );
      expect(response, hasStatus(401));
      expect(response.headers['www-authenticate'], 'Basic realm="oauth2"');
      expect(response.body, contains('invalid_client'));
    });

    test('a client_secret of the form must be of the Basic header', () async {
      var basic = 'Basic ${base64.encode('foo:bar'.codeUnits)}';
      var response = await exchange(
        {'client_id': 'foo', 'client_secret': 'other'},
        headers: {'Authorization': basic},
      );
      expect(response, hasStatus(400));
      expect(response.body, contains('invalid_request'));
      expect(
        await exchange(
          {'client_id': 'foo', 'client_secret': 'bar'},
          headers: {'Authorization': basic},
        ),
        hasStatus(200),
      );
    });

    test('a client may authenticate with Basic, without client_id', () async {
      var basic = 'Basic ${base64.encode('foo:bar'.codeUnits)}';
      expect(
        await exchange({}, headers: {'Authorization': basic}),
        hasStatus(200),
      );
      var wrong = 'Basic ${base64.encode('foo:wrong'.codeUnits)}';
      expect(
        await exchange({}, headers: {'Authorization': wrong}),
        hasStatus(401),
      );
    });

    test(
      'a device code request with a wrong secret is invalid_client',
      () async {
        var response = await client.post(
          Uri.parse('/oauth2/token'),
          body: {'client_id': 'foo', 'client_secret': 'wrong'},
        );
        expect(response, hasStatus(401));
        expect(response.body, contains('invalid_client'));
      },
    );

    // The rationale for only testing one possible error response is that
    // they all only differ in terms of the `code` string sent down,
    // which is chosen by the end user.
    //
    // The logic for throwing errors and turning them into responses
    // has already been tested.
    test('failure', () async {
      var response = await client.post(
        Uri.parse('/oauth2/token'),
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'client_id': 'device',
          'device_code': 'brute',
        },
      );

      print("[Client] ${response.headers}");
      print("[Client] ${response.body}");
      expect(
        response,
        allOf(
          hasStatus(400),
          isJson({
            'error': 'slow_down',
            'error_description': 'Ho, brother! Ho, whoa, whoa, whoa now! You got too much dip on your chip!',
          }),
        ),
      );
    });
  });
}

class _AuthorizationServer
    extends AuthorizationServer<PseudoApplication, PseudoUser> {
  var logger = Logger('AuthorizationServer');

  @override
  PseudoApplication? findClient(String? clientId) {
    return switch (clientId) {
      'foo' => pseudoApplication,
      'device' => _deviceClient,
      _ => null,
    };
  }

  @override
  Future<bool> verifyClient(
    PseudoApplication client,
    String? clientSecret,
  ) async {
    // A public client gives no secret.
    return identical(client, _deviceClient)
        ? clientSecret == null
        : client.secret == clientSecret;
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

/// A public client, of a device, without a secret.
const _deviceClient = PseudoApplication('device', '', 'http://foo.bar');
