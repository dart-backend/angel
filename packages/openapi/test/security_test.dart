import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_openapi/angel3_openapi.dart';
import 'package:test/test.dart';

/// A scheme of an API key, of a middleware of its own.
const apiKey = SecurityScheme('apiKey', {
  'type': 'apiKey',
  'in': 'header',
  'name': 'X-API-Key',
});

void main() {
  late OpenApi openApi;
  late Angel app;

  Map<String, dynamic> document() => openApi.documentOf(app);

  Map operationOf(String method, String path) =>
      ((document()['paths'] as Map)[path] as Map)[method] as Map;

  setUp(() {
    openApi = OpenApi(title: 'T');
    app = Angel();
  });

  test('a route of requireAuthentication needs a bearer JWT, or a 403', () {
    app.get(
      '/me',
      (req, res) => {},
      middleware: [requireAuthentication<Map>()],
    );
    app.get('/public', (req, res) => {});
    var me = operationOf('get', '/me');
    expect(me['security'], [
      {'bearer': <String>[]},
    ]);
    expect((me['responses'] as Map).keys, ['200', '403']);
    expect(
      ((document()['components'] as Map)['securitySchemes'] as Map)['bearer'],
      SecurityScheme.bearer.definition,
    );
    expect(operationOf('get', '/public'), isNot(contains('security')));
  });

  test('of a handler of chain, as the README of angel3_auth protects one', () {
    app.get(
      '/me',
      chain([requireAuthentication<Map>(), (req, res) => <String, String>{}]),
    );
    expect(operationOf('get', '/me')['security'], [
      {'bearer': <String>[]},
    ]);
  });

  test('of forceBasicAuth, a bearer JWT or Basic, or a 401', () {
    app.chain([forceBasicAuth<Map>()]).get('/admin', (req, res) => {});
    var admin = operationOf('get', '/admin');
    expect(admin['security'], [
      {'bearer': <String>[]},
      {'basic': <String>[]},
    ]);
    expect((admin['responses'] as Map).keys, ['200', '401']);
    expect(((document()['components'] as Map)['securitySchemes'] as Map).keys, {
      'bearer',
      'basic',
    });
  });

  test('of the services of an app chained behind it', () {
    var api = Angel()..use('/todos', MapService());
    app.chain([requireAuthentication<Map>()]).mount('/api', api);
    app.use('/open', MapService());
    for (var (method, path) in [
      ('get', '/api/todos'),
      ('post', '/api/todos'),
      ('get', '/api/todos/{id}'),
      ('delete', '/api/todos/{id}'),
    ]) {
      var operation = operationOf(method, path);
      expect(operation['security'], [
        {'bearer': <String>[]},
      ], reason: '$method $path');
      expect(operation['responses'] as Map, contains('403'));
      // Documented as the service's operation.
      expect(operation['tags'], ['api/todos']);
    }
    expect(operationOf('get', '/open'), isNot(contains('security')));
  });

  test('of every requirement of its handlers, one scheme of each', () {
    var key = SecurityRequirement([apiKey])
        .tag((RequestContext req, ResponseContext res) => true);
    app.get(
      '/both',
      (req, res) => {},
      middleware: [forceBasicAuth<Map>(), key],
    );
    expect(operationOf('get', '/both')['security'], [
      {'bearer': <String>[], 'apiKey': <String>[]},
      {'basic': <String>[], 'apiKey': <String>[]},
    ]);
  });

  test('an operation described with its own security keeps it', () {
    app.get(
      '/me',
      (req, res) => {},
      middleware: [requireAuthentication<Map>()],
    );
    openApi.describe(
      'GET',
      '/me',
      OpenApiOperation(
        extra: {
          'security': [
            {'oauth': <String>[]},
          ],
        },
      ),
    );
    expect(operationOf('get', '/me')['security'], [
      {'oauth': <String>[]},
    ]);
  });

  test('the security schemes of extra join those of the handlers', () {
    openApi = OpenApi(
      title: 'T',
      schemas: {
        'User': {'type': 'object'},
      },
      extra: {
        'components': {
          'securitySchemes': {
            'oauth': {'type': 'oauth2', 'flows': <String, dynamic>{}},
          },
        },
      },
    );
    app.get(
      '/me',
      (req, res) => {},
      middleware: [requireAuthentication<Map>()],
    );
    var components = document()['components'] as Map;
    expect((components['securitySchemes'] as Map).keys, {'bearer', 'oauth'});
    expect(components['schemas'], contains('User'));
  });
}
