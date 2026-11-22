import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_openapi/angel3_openapi.dart';

Future<void> main() async {
  var app = Angel();

  var openApi = OpenApi(
    title: 'Todo API',
    version: '1.0.0',
    schemas: {
      'Todo': {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
          'text': {'type': 'string'},
          'completed': {'type': 'boolean'},
        },
      },
    },
  );
  // GET /openapi.json, and the Swagger UI page at GET /docs.
  await app.configure(openApi.configureServer);

  // A service documents its own operations: GET /todos, POST /todos,
  // GET, PATCH, PUT and DELETE /todos/{id}.
  app.use('/todos', MapService());
  openApi.describeService('todos', schema: OpenApi.ref('Todo'));

  // A route documents its method, path and path parameters; describe adds
  // the rest.
  app.get('/stats/int:year', (req, res) => {'year': req.params['year']});
  openApi.describe(
    'GET',
    'stats/int:year',
    OpenApiOperation(
      summary: 'The statistics of a year',
      tags: ['stats'],
      responses: {200: OpenApiResponse('The statistics')},
    ),
  );

  app.fallback((req, res) => throw AngelHttpException.notFound());

  var http = AngelHttp(app);
  await http.startServer('127.0.0.1', 3000);
  print('Swagger UI at ${http.uri.replace(path: '/docs')}');
}
