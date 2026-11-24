import 'dart:convert';
import 'dart:io' show ContentType;

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:angel3_openapi/angel3_openapi.dart';
import 'package:test/test.dart';

/// The status, content type and body of a GET of [path] of [app].
Future<(int, String?, String)> get(Angel app, String path) async {
  var rq = MockHttpRequest('GET', Uri.parse(path));
  await rq.close();
  await AngelHttp(app).handleRequest(rq);
  var body = await rq.response.transform(utf8.decoder).join();
  return (
    rq.response.statusCode,
    rq.response.headers.contentType?.mimeType,
    body,
  );
}

final userSchema = {
  'type': 'object',
  'properties': {
    'name': {'type': 'string'},
  },
};

/// A service of integer ids, as an `OrmService<int?, ...>`.
class CounterService extends Service<int?, Map<String, dynamic>> {}

/// A service of `double` ids.
class ReadingService extends Service<double, Map<String, dynamic>> {}

/// A service of query parameters, and errors, of its own.
class SearchService extends Service<String?, Map<String, dynamic>>
    implements DocumentedService {
  @override
  Map<String, Map<String, dynamic>> get indexQueryParameters => {
    'q': {'type': 'string'},
  };

  @override
  Map<String, Map<int, String>> get errorResponses => {
    'create': {409: 'Taken'},
    'remove': {423: 'Locked'},
  };
}

/// An app of a few kinds of routes, and a service.
Angel appOf(OpenApi openApi) {
  var app = Angel();
  app.get('/', (req, res) => 'home');
  app.get('/users/:id', (req, res) => {}).name = 'readUser';
  app.post('/users', (req, res) => {});
  app.group('/api/v1', (router) {
    router.get('/items/int:id', (req, res) => {});
    router.get('/files/:name([a-z]+)', (req, res) => {});
    router.get('/pages/:page?', (req, res) => {});
  });
  app.get('/assets/*', (req, res) => 'asset');
  app.all('/anything', (req, res) => true);
  app.use('/todos', MapService());
  app.fallback((req, res) => throw AngelHttpException.notFound());
  return app;
}

void main() {
  group('openApiPathsOf', () {
    test('of constants and parameters', () {
      var [p] = openApiPathsOf('users/:id/posts/:post');
      expect(p.path, '/users/{id}/posts/{post}');
      expect(p.parameters.map((p) => p.name), ['id', 'post']);
      expect(p.parameters.first.schema, {'type': 'string'});
    });

    test('of the root', () {
      expect(openApiPathsOf('').single.path, '/');
      expect(openApiPathsOf('/').single.path, '/');
    });

    test('of typed parameters', () {
      expect(openApiPathsOf('items/int:id').single.parameters.single.schema, {
        'type': 'integer',
      });
      expect(openApiPathsOf('x/double:v').single.parameters.single.schema, {
        'type': 'number',
      });
      expect(openApiPathsOf('x/num:v').single.parameters.single.schema, {
        'type': 'number',
      });
    });

    test('of a parameter of a regular expression', () {
      var [p] = openApiPathsOf('files/:name([a-z]+)');
      expect(p.path, '/files/{name}');
      expect(p.parameters.single.schema, {
        'type': 'string',
        'pattern': '^[a-z]+\$',
      });
    });

    test('of text around a parameter', () {
      expect(openApiPathsOf('v:version/api').single.path, '/v{version}/api');
      expect(
        openApiPathsOf('file/:name.json').single.path,
        '/file/{name}.json',
      );
    });

    test('of an optional parameter, with and without it', () {
      expect(openApiPathsOf('pages/:page?').map((p) => p.path), [
        '/pages/{page}',
        '/pages',
      ]);
      expect(openApiPathsOf('a/:b?/:c?').map((p) => p.path).toSet(), {
        '/a/{b}/{c}',
        '/a/{b}',
        '/a/{c}',
        '/a',
      });
    });

    test('of a wildcard, none', () {
      expect(openApiPathsOf('assets/*'), isEmpty);
      expect(openApiPathsOf('*'), isEmpty);
    });
  });

  group('documentOf', () {
    late OpenApi openApi;
    late Map<String, dynamic> doc;
    late Map<String, dynamic> paths;

    setUp(() {
      openApi = OpenApi(
        title: 'Test API',
        version: '2.0.0',
        description: 'For tests',
        servers: ['https://api.example.com'],
        schemas: {'User': userSchema, 'Todo': userSchema},
      );
      openApi.describe(
        'GET',
        '/users/{id}',
        OpenApiOperation(
          summary: 'Read a user',
          tags: ['users'],
          queryParameters: {
            'fields': {'type': 'string'},
          },
          responses: {
            200: OpenApiResponse('The user', schema: OpenApi.ref('User')),
            404: OpenApiResponse('No such user'),
          },
        ),
      );
      openApi.describe(
        'POST',
        'users',
        OpenApiOperation(
          requestBody: OpenApi.ref('User'),
          extra: {
            'security': [
              {'bearer': <String>[]},
            ],
          },
        ),
      );
      openApi.describeService(
        '/todos',
        schema: OpenApi.ref('Todo'),
        tag: 'todos',
      );
      var app = appOf(openApi);
      doc = openApi.documentOf(app);
      paths = doc['paths'] as Map<String, dynamic>;
    });

    test('has the info, servers and schemas given', () {
      expect(doc['openapi'], '3.1.0');
      expect(doc['info'], {
        'title': 'Test API',
        'version': '2.0.0',
        'description': 'For tests',
      });
      expect(doc['servers'], [
        {'url': 'https://api.example.com'},
      ]);
      expect((doc['components'] as Map)['schemas'], contains('User'));
    });

    test('documents each route of a method and a path', () {
      expect(paths.keys, containsAll(['/', '/users/{id}', '/users']));
      expect((paths['/'] as Map).keys, ['get']);
      expect(paths['/'], {
        'get': {
          'responses': {
            '200': {'description': 'OK'},
          },
        },
      });
    });

    test('of the routes of groups, with their parameters', () {
      var item = (paths['/api/v1/items/{id}'] as Map)['get'] as Map;
      expect(item['parameters'], [
        {
          'name': 'id',
          'in': 'path',
          'required': true,
          'schema': {'type': 'integer'},
        },
      ]);
      expect(paths, contains('/api/v1/files/{name}'));
      expect(paths, contains('/api/v1/pages/{page}'));
      expect(paths, contains('/api/v1/pages'));
    });

    test('leaves out wildcards and routes of any method', () {
      expect(paths.keys.where((p) => p.contains('assets')), isEmpty);
      expect(paths, isNot(contains('/anything')));
    });

    test('gives a route its name as its operationId', () {
      var read = (paths['/users/{id}'] as Map)['get'] as Map;
      expect(read['operationId'], 'readUser');
    });

    test('adds what describe gives', () {
      var read = (paths['/users/{id}'] as Map)['get'] as Map;
      expect(read['summary'], 'Read a user');
      expect(read['tags'], ['users']);
      expect(read['parameters'], [
        {
          'name': 'id',
          'in': 'path',
          'required': true,
          'schema': {'type': 'string'},
        },
        {
          'name': 'fields',
          'in': 'query',
          'schema': {'type': 'string'},
        },
      ]);
      expect(read['responses'], {
        '200': {
          'description': 'The user',
          'content': {
            'application/json': {
              'schema': {r'$ref': '#/components/schemas/User'},
            },
          },
        },
        '404': {'description': 'No such user'},
      });
      var create = (paths['/users'] as Map)['post'] as Map;
      expect(create['requestBody'], {
        'required': true,
        'content': {
          'application/json': {
            'schema': {r'$ref': '#/components/schemas/User'},
          },
        },
      });
      expect(create['security'], [
        {'bearer': <String>[]},
      ]);
    });

    test('documents the operations of a service', () {
      expect((paths['/todos'] as Map).keys.toSet(), {'get', 'post'});
      expect((paths['/todos/{id}'] as Map).keys.toSet(), {
        'get',
        'patch',
        'put',
        'delete',
      });
      var index = (paths['/todos'] as Map)['get'] as Map;
      expect(index['operationId'], 'todosIndex');
      expect(index['tags'], ['todos']);
      expect(((index['responses'] as Map)['200'] as Map)['content'], {
        'application/json': {
          'schema': {
            'type': 'array',
            'items': {r'$ref': '#/components/schemas/Todo'},
          },
        },
      });
      var read = (paths['/todos/{id}'] as Map)['get'] as Map;
      expect((read['responses'] as Map).keys, ['200', '400', '404']);
      expect(
        (((paths['/todos'] as Map)['get'] as Map)['responses'] as Map).keys,
        ['200', '400'],
      );
      expect((read['parameters'] as List).single['name'], 'id');
    });

    test('the create of a service is a 201, as the service responds', () async {
      var create = (paths['/todos'] as Map)['post'] as Map;
      expect((create['responses'] as Map).keys, ['201', '400']);
      expect(((create['responses'] as Map)['201'] as Map)['content'], {
        'application/json': {
          'schema': {r'$ref': '#/components/schemas/Todo'},
        },
      });

      var rq = MockHttpRequest('POST', Uri.parse('/todos'))
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'text': 'Clean'}));
      await rq.close();
      await AngelHttp(appOf(openApi)).handleRequest(rq);
      expect(rq.response.statusCode, 201);
    });

    test('the id of a service is of the type of its ids', () {
      var app = appOf(openApi)
        ..use('/counters', CounterService())
        ..use('/readings', ReadingService());
      var paths = openApi.documentOf(app)['paths'] as Map;
      Object? idType(String path) =>
          (((((paths[path] as Map)['get'] as Map)['parameters'] as List).single
                  as Map)['schema']
              as Map)['type'];
      expect(idType('/todos/{id}'), 'string');
      expect(idType('/counters/{id}'), 'integer');
      expect(idType('/readings/{id}'), 'number');
    });

    test('the operations of a service have the errors it tells of', () {
      var app = appOf(openApi)..use('/search', SearchService());
      var paths = openApi.documentOf(app)['paths'] as Map;
      Map responsesOf(String path, String method) =>
          ((paths[path] as Map)[method] as Map)['responses'] as Map;
      expect(responsesOf('/search', 'post').keys, ['201', '400', '409']);
      expect(responsesOf('/search', 'post')['409'], {'description': 'Taken'});
      expect(responsesOf('/search/{id}', 'delete').keys, [
        '200',
        '400',
        '404',
        '423',
      ]);
      expect(responsesOf('/search/{id}', 'get').keys, ['200', '400', '404']);
      // A MapService tells of none.
      expect(responsesOf('/todos', 'post').keys, ['201', '400']);
    });

    test('the index of a service has its query parameters', () {
      var app = appOf(openApi)
        ..use('/notes', MapService(allowQuery: false))
        ..use('/search', SearchService())
        ..use('/counters', CounterService());
      var paths = openApi.documentOf(app)['paths'] as Map;
      Object? parametersOf(String path) =>
          ((paths[path] as Map)['get'] as Map)['parameters'];
      expect(parametersOf('/todos'), [
        {
          'name': r'$sort',
          'in': 'query',
          'schema': {'type': 'string', 'description': 'The field to sort by'},
        },
        {
          'name': r'$limit',
          'in': 'query',
          'schema': {
            'type': 'integer',
            'minimum': 0,
            'description': 'The most items to give',
          },
        },
      ]);
      expect(parametersOf('/notes'), isNull);
      expect(parametersOf('/search'), [
        {
          'name': 'q',
          'in': 'query',
          'schema': {'type': 'string'},
        },
      ]);
      // Not a DocumentedService.
      expect(parametersOf('/counters'), isNull);
    });

    test('describe replaces the operation of a service', () {
      openApi.describe(
        'DELETE',
        '/todos/{id}',
        OpenApiOperation(summary: 'Delete a todo', deprecated: true),
      );
      var app = appOf(openApi);
      var remove =
          ((openApi.documentOf(app)['paths'] as Map)['/todos/{id}']
                  as Map)['delete']
              as Map;
      expect(remove['summary'], 'Delete a todo');
      expect(remove['deprecated'], true);
      expect((remove['parameters'] as List).single['name'], 'id');
    });

    test('include leaves out the routes it refuses', () {
      var only = OpenApi(
        title: 'T',
        include: (route) => !route.path.contains('users'),
      );
      var keys = (only.documentOf(appOf(only))['paths'] as Map).keys;
      expect(keys.where((k) => k.startsWith('/users')), isEmpty);
      expect(keys, contains('/'));
    });

    test('extra adds to the document', () {
      var withSecurity = OpenApi(
        title: 'T',
        extra: {
          'security': [
            {'bearer': <String>[]},
          ],
        },
      );
      expect(withSecurity.documentOf(Angel())['security'], [
        {'bearer': <String>[]},
      ]);
    });
  });

  group('configureServer', () {
    test('serves the document, of routes added after it', () async {
      var openApi = OpenApi(title: 'T');
      var app = Angel();
      await app.configure(openApi.configureServer);
      app.get('/later', (req, res) => 'later');
      var (status, type, body) = await get(app, '/openapi.json');
      expect(status, 200);
      expect(type, 'application/json');
      var paths = (json.decode(body) as Map)['paths'] as Map;
      expect(paths.keys, ['/later']);
    });

    test('serves the Swagger UI page of the document', () async {
      var openApi = OpenApi(title: '<Test & API>');
      var app = Angel();
      await app.configure(openApi.configureServer);
      var (status, type, body) = await get(app, '/docs');
      expect(status, 200);
      expect(type, 'text/html');
      expect(body, contains('<title>&lt;Test &amp; API&gt;</title>'));
      expect(body, contains('swagger-ui-dist@5.34.1/swagger-ui-bundle.js'));
      expect(body, contains('url: "/openapi.json"'));
    });

    test('of other paths, or no page', () async {
      var openApi = OpenApi(
        title: 'T',
        documentPath: '/api/spec.json',
        uiPath: null,
      );
      var app = Angel();
      await app.configure(openApi.configureServer);
      app.fallback((req, res) => throw AngelHttpException.notFound());
      expect((await get(app, '/api/spec.json')).$1, 200);
      expect((await get(app, '/docs')).$1, 404);
      expect(
        openApi.swaggerUiPage('/api/spec.json'),
        contains('"/api/spec.json"'),
      );
    });

    test('in production, builds it again after describe', () {
      var openApi = OpenApi(title: 'T');
      var app = Angel(environment: AngelEnvironment('production'));
      app.get('/a', (req, res) => 'a');
      openApi.documentOf(app);
      openApi.describe('GET', '/a', OpenApiOperation(summary: 'A'));
      var a = ((openApi.documentOf(app)['paths'] as Map)['/a'] as Map)['get'];
      expect((a as Map)['summary'], 'A');
    });

    test('in production, builds the document once', () async {
      var openApi = OpenApi(title: 'T');
      var app = Angel(environment: AngelEnvironment('production'));
      app.get('/a', (req, res) => 'a');
      var first = openApi.documentOf(app);
      app.get('/b', (req, res) => 'b');
      expect(identical(openApi.documentOf(app), first), isTrue);
    });
  });

  group('a mounted app', () {
    late OpenApi openApi;
    late Map paths;

    setUp(() {
      var v2 = Angel()..use('/counters', CounterService());
      var api = Angel()
        ..use('/todos', MapService())
        ..get('/health', (req, res) => 'ok')
        ..mount('/v2', v2);
      var org = Angel()..use('/members', MapService());
      var app = Angel()
        ..mount('/api', api)
        ..mount('/orgs/:org', org);
      openApi = OpenApi(title: 'T')..describeService('api/todos', tag: 'Todos');
      paths = openApi.documentOf(app)['paths'] as Map;
    });

    test('documents its services as services, under its path', () {
      expect((paths['/api/todos'] as Map).keys.toSet(), {'get', 'post'});
      expect((paths['/api/todos/{id}'] as Map).keys.toSet(), {
        'get',
        'patch',
        'put',
        'delete',
      });
      var create = (paths['/api/todos'] as Map)['post'] as Map;
      expect(create['operationId'], 'todosCreate');
      expect(create['tags'], ['Todos']);
      expect((create['responses'] as Map).keys, ['201', '400']);
      var index = (paths['/api/todos'] as Map)['get'] as Map;
      expect(
        [for (var p in index['parameters'] as List) (p as Map)['name']],
        [r'$sort', r'$limit'],
      );
    });

    test('and those of an app mounted in it', () {
      var read = (paths['/api/v2/counters/{id}'] as Map)['get'] as Map;
      expect(read['tags'], ['api/v2/counters']);
      var id = (read['parameters'] as List).single as Map;
      expect((id['schema'] as Map)['type'], 'integer');
    });

    test('and its other routes as routes', () {
      expect((paths['/api/health'] as Map).keys, ['get']);
    });

    test('of a path of a parameter, as plain routes', () {
      var members = paths['/orgs/{org}/members'] as Map;
      expect(members, contains('get'));
      expect((members['get'] as Map)['operationId'], isNot('membersIndex'));
    });
  });
}
