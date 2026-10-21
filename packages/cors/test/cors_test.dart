import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_cors/angel3_cors.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  Angel? app;
  late AngelHttp server;
  http.Client? client;

  setUp(() async {
    app = Angel()
      ..options('/credentials', cors(CorsOptions(credentials: true)))
      ..options(
        '/credentials_d',
        dynamicCors((req, res) => CorsOptions(credentials: true)),
      )
      ..options(
        '/headers',
        cors(CorsOptions(exposedHeaders: ['x-foo', 'x-bar'])),
      )
      ..options('/max_age', cors(CorsOptions(maxAge: 250)))
      ..options('/methods', cors(CorsOptions(methods: ['GET', 'POST'])))
      ..get(
        '/originl',
        chain([
          cors(CorsOptions(origin: ['foo.bar', 'baz.quux'])),
          (req, res) => req.headers!['origin'],
        ]),
      )
      ..options(
        '/originl',
        chain([
          cors(CorsOptions(origin: ['foo.bar', 'baz.quux'])),
          (req, res) => 'app options',
        ]),
      )
      ..get(
        '/origins',
        chain([
          cors(CorsOptions(origin: 'foo.bar')),
          (req, res) => req.headers!['origin'],
        ]),
      )
      ..get(
        '/originr',
        chain([
          cors(CorsOptions(origin: RegExp(r'^foo\.[^x]+$'))),
          (req, res) => req.headers!['origin'],
        ]),
      )
      ..get(
        '/originp',
        chain([
          cors(CorsOptions(origin: (String s) => s.endsWith('.bar'))),
          (req, res) => req.headers!['origin'],
        ]),
      )
      ..options('/status', cors(CorsOptions(successStatus: 418)))
      ..get(
        '/disabled',
        chain([cors(CorsOptions(origin: false)), (req, res) => 'ok']),
      )
      ..get(
        '/async',
        chain([
          cors(CorsOptions(origin: (String s) async => s == 'foo.bar')),
          (req, res) => 'ok',
        ]),
      )
      ..get(
        '/vary',
        chain([
          (req, res) {
            res.headers['vary'] = 'accept-encoding';
            return true;
          },
          cors(CorsOptions(origin: ['foo.bar'])),
          (req, res) => 'ok',
        ]),
      )
      ..options(
        '/continue',
        chain([
          cors(CorsOptions(preflightContinue: true)),
          (req, res) => 'continued',
        ]),
      )
      ..options('/plain', chain([cors(), (req, res) => 'app options']))
      ..fallback(cors(CorsOptions()))
      ..post('/', (req, res) async {
        res.write('hello world');
      })
      ..fallback((req, res) => throw AngelHttpException.notFound());

    server = AngelHttp(app!);
    await server.startServer('127.0.0.1', 0);
    client = http.Client();
  });

  tearDown(() async {
    await server.close();
    app = null;
    client = null;
  });

  Future<http.Response> preflight(String path) => client!
      .send(
        http.Request('OPTIONS', server.uri.replace(path: path))
          ..headers['access-control-request-method'] = 'POST',
      )
      .then(http.Response.fromStream);

  test('status 204 by default', () async {
    var response = await preflight('/max_age');
    expect(response.statusCode, 204);
  });

  test('content length 0 by default', () async {
    var response = await preflight('/max_age');
    expect(response.contentLength, 0);
  });

  test('custom successStatus', () async {
    var response = await preflight('/status');
    expect(response.statusCode, 418);
  });

  test('max age', () async {
    var response = await preflight('/max_age');
    expect(response.headers['access-control-max-age'], '250');
  });

  test('methods', () async {
    var response = await preflight('/methods');
    expect(response.headers['access-control-allow-methods'], 'GET,POST');
  });

  test('dynamicCors.credentials', () async {
    var response = await preflight('/credentials_d');
    expect(response.headers['access-control-allow-credentials'], 'true');
  });

  test('credentials', () async {
    var response = await preflight('/credentials');
    expect(response.headers['access-control-allow-credentials'], 'true');
  });

  test('exposed headers', () async {
    var response = await preflight('/headers');
    expect(response.headers['access-control-expose-headers'], 'x-foo,x-bar');
  });

  test('invalid origin', () async {
    var response = await client!.get(
      server.uri.replace(path: '/originl'),
      headers: {'origin': 'foreign'},
    );
    expect(response.headers['access-control-allow-origin'], isNull);
    expect(response.headers['vary'], 'origin');
  });

  test('list origin', () async {
    var response = await client!.get(
      server.uri.replace(path: '/originl'),
      headers: {'origin': 'foo.bar'},
    );
    expect(response.headers['access-control-allow-origin'], 'foo.bar');
    expect(response.headers['vary'], 'origin');
    response = await client!.get(
      server.uri.replace(path: '/originl'),
      headers: {'origin': 'baz.quux'},
    );
    expect(response.headers['access-control-allow-origin'], 'baz.quux');
    expect(response.headers['vary'], 'origin');
  });

  test('string origin', () async {
    var response = await client!.get(
      server.uri.replace(path: '/origins'),
      headers: {'origin': 'foo.bar'},
    );
    expect(response.headers['access-control-allow-origin'], 'foo.bar');
    // The same for every origin, so caches need not keep them apart.
    expect(response.headers['vary'], isNull);
  });

  test('regex origin', () async {
    var response = await client!.get(
      server.uri.replace(path: '/originr'),
      headers: {'origin': 'foo.bar'},
    );
    expect(response.headers['access-control-allow-origin'], 'foo.bar');
    expect(response.headers['vary'], 'origin');
  });

  test('predicate origin', () async {
    var response = await client!.get(
      server.uri.replace(path: '/originp'),
      headers: {'origin': 'foo.bar'},
    );
    expect(response.headers['access-control-allow-origin'], 'foo.bar');
    expect(response.headers['vary'], 'origin');
  });

  test('POST works', () async {
    final response = await client!.post(server.uri);
    expect(response.statusCode, equals(200));
    print('Response: ${response.body}');
    print('Headers: ${response.headers}');
    expect(response.headers['access-control-allow-origin'], equals('*'));
  });

  test('mirror headers on a preflight only', () async {
    var response = await client!
        .send(
          http.Request('OPTIONS', server.uri)
            ..headers['access-control-request-method'] = 'POST'
            ..headers['access-control-request-headers'] = 'foo',
        )
        .then(http.Response.fromStream);
    expect(response.headers['access-control-allow-headers'], 'foo');

    response = await client!.post(
      server.uri,
      headers: {'access-control-request-headers': 'foo'},
    );
    expect(response.statusCode, 200);
    expect(response.headers['access-control-allow-headers'], isNull);
  });

  test('a request without an origin is not refused', () async {
    var response = await client!.get(server.uri.replace(path: '/originp'));
    expect(response.statusCode, 200);
    expect(response.headers['access-control-allow-origin'], isNull);
  });

  test('origin: false disables CORS', () async {
    var response = await client!.get(
      server.uri.replace(path: '/disabled'),
      headers: {'origin': 'foo.bar'},
    );
    expect(response.headers['access-control-allow-origin'], isNull);
  });

  test('an origin of an unknown type is an ArgumentError', () {
    for (var origin in [
      Uri.parse('https://foo.bar'),
      ['foo.bar', 1],
      (String s) => null,
    ]) {
      expect(() => CorsOptions(origin: origin), throwsArgumentError);
    }
  });

  test('an async predicate is awaited', () async {
    var allowed = await client!.get(
      server.uri.replace(path: '/async'),
      headers: {'origin': 'foo.bar'},
    );
    expect(allowed.headers['access-control-allow-origin'], 'foo.bar');
    var refused = await client!.get(
      server.uri.replace(path: '/async'),
      headers: {'origin': 'evil.com'},
    );
    expect(refused.headers['access-control-allow-origin'], isNull);
  });

  test('Vary is added to, not replaced', () async {
    var response = await client!.get(
      server.uri.replace(path: '/vary'),
      headers: {'origin': 'foo.bar'},
    );
    expect(response.headers['vary'], 'accept-encoding, origin');
  });

  test('preflightContinue leaves the response to later handlers', () async {
    var response = await preflight('/continue');
    expect(response.statusCode, 200);
    expect(response.body, '"continued"');
    expect(response.headers['access-control-allow-methods'], isNotNull);
  });

  test('an OPTIONS request that is not a preflight continues', () async {
    var rq = http.Request('OPTIONS', server.uri.replace(path: '/plain'));
    var response = await client!.send(rq).then(http.Response.fromStream);
    expect(response.body, '"app options"');
  });

  test('a preflight from a refused origin is answered without CORS', () async {
    var response = await client!
        .send(
          http.Request('OPTIONS', server.uri.replace(path: '/originl'))
            ..headers['origin'] = 'evil.com'
            ..headers['access-control-request-method'] = 'GET',
        )
        .then(http.Response.fromStream);
    expect(response.statusCode, 204);
    expect(response.headers['access-control-allow-origin'], isNull);
  });

  test('a method override does not make a preflight', () async {
    var response = await client!.post(
      server.uri.replace(path: '/plain'),
      headers: {
        'x-http-method-override': 'OPTIONS',
        'access-control-request-method': 'POST',
      },
    );
    // Routed as OPTIONS, but sent as a POST, so not answered by cors.
    expect(response.body, '"app options"');
  });
}
