import 'dart:async';
import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:test/test.dart';

final AngelAuth<Map<String, String>> auth = AngelAuth<Map<String, String>>(
    serializer: (user) async => 1337, deserializer: (id) async => sampleUser);
var headers = <String, String>{'accept': 'application/json'};
var localOpts = AngelAuthOptions<Map<String, String>>(
    failureRedirect: '/failure', successRedirect: '/success');
Map<String, String> sampleUser = {'hello': 'world'};

Future<Map<String, String>?> verifier(
    String? username, String? password) async {
  if (username == 'username' && password == 'password') {
    return sampleUser;
  } else {
    return null;
  }
}

Future wireAuth(Angel app) async {
  //auth.serializer = (user) async => 1337;
  //auth.deserializer = (id) async => sampleUser;

  auth.strategies['local'] = LocalAuthStrategy(verifier);
  await app.configure(auth.configureServer);
}

void main() async {
  Angel app;
  late AngelHttp angelHttp;
  late http.Client client;
  String? url;
  String? basicAuthUrl;

  setUp(() async {
    client = http.Client();
    app = Angel();
    angelHttp = AngelHttp(app, useZone: false);
    await app.configure(wireAuth);
    app.get('/hello', (req, res) {
      // => 'Woo auth'
      return 'Woo auth';
    }); //, middleware: [auth.authenticate('local')]);
    app.post('/login', (req, res) => 'This should not be shown',
        middleware: [auth.authenticate('local', localOpts)]);
    app.get('/success', (req, res) => 'yep', middleware: [
      requireAuthentication<Map<String, String>>(),
    ]);
    app.get('/failure', (req, res) => 'nope');

    app.logger = Logger('angel_auth')
      ..onRecord.listen((rec) {
        if (rec.error != null) {
          print(rec.error);
          print(rec.stackTrace);
        }
      });

    var server = await angelHttp.startServer('127.0.0.1', 0);
    url = 'http://${server.address.host}:${server.port}';
    basicAuthUrl =
        'http://username:password@${server.address.host}:${server.port}';
  });

  tearDown(() async {
    await angelHttp.close();
    //client = null;
    url = null;
    basicAuthUrl = null;
  });

  test('can use "auth" as middleware', () async {
    var response = await client.get(Uri.parse('$url/success'),
        headers: {'Accept': 'application/json'});
    print(response.body);
    expect(response.statusCode, equals(403));
  });

  test('successRedirect', () async {
    var postData = {'username': 'username', 'password': 'password'};
    var response = await client.post(Uri.parse('$url/login'),
        body: json.encode(postData),
        headers: {'content-type': 'application/json'});
    expect(response.statusCode, equals(302));
    expect(response.headers['location'], equals('/success'));
  });

  test('failureRedirect', () async {
    var postData = {'username': 'password', 'password': 'username'};
    var response = await client.post(Uri.parse('$url/login'),
        body: json.encode(postData),
        headers: {'content-type': 'application/json'});
    print('Login response: ${response.body}');
    expect(response.headers['location'], equals('/failure'));
    expect(response.statusCode, equals(401));
  });

  test('allow basic', () async {
    var authString = base64.encode('username:password'.runes.toList());
    var response = await client.get(Uri.parse('$url/hello'),
        headers: {'authorization': 'Basic $authString'});
    print(response.statusCode);
    print(response.body);
    expect(response.body, equals('"Woo auth"'));
  });

  test('allow basic via URL encoding', () async {
    var response = await client.get(Uri.parse('$basicAuthUrl/hello'));
    expect(response.body, equals('"Woo auth"'));
  });

  test('force basic', () async {
    auth.strategies.clear();
    auth.strategies['local'] =
        LocalAuthStrategy(verifier, forceBasic: true, realm: 'test');
    var response = await client.get(Uri.parse('$url/hello'), headers: {
      'accept': 'application/json',
      'content-type': 'application/json'
    });
    print('Header = ${response.headers}');
    print('Body <${response.body}>');
    var head = response.headers['www-authenticate'];
    expect(head, equals('Basic realm="test"'));
  });
}
