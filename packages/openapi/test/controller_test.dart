import 'package:angel3_container_mirrors/angel3_container_mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_openapi/angel3_openapi.dart';
import 'package:test/test.dart';

@Expose('/users')
class UserController extends Controller {
  @Expose('/:id')
  @OpenApiOperation(
    summary: 'Read a user',
    tags: ['users'],
    responses: {200: OpenApiResponse('The user'), 404: OpenApiResponse('None')},
  )
  Map<String, dynamic> read(String id) => {'id': id};

  @Expose('/', method: 'POST', as: 'createUser')
  @OpenApiOperation(summary: 'Create a user', operationId: 'createUser')
  Map<String, dynamic> create() => {};

  @Expose('/plain')
  Map<String, dynamic> plain() => {};
}

Map<String, dynamic> operationOf(Map doc, String method, String path) =>
    ((doc['paths'] as Map)[path] as Map)[method] as Map<String, dynamic>;

void main() {
  late Angel app;

  setUp(() async {
    app = Angel(reflector: const MirrorsReflector());
    await app.configure(UserController().configureServer);
  });

  test('a controller method is described by its @OpenApiOperation', () {
    var doc = OpenApi(title: 'T').documentOf(app);
    var read = operationOf(doc, 'get', '/users/{id}');
    expect(read['summary'], 'Read a user');
    expect(read['tags'], ['users']);
    expect((read['responses'] as Map).keys, ['200', '404']);
    expect((read['parameters'] as List).single['name'], 'id');
  });

  test('of a method of another route name, with @Expose(as: ...)', () {
    var doc = OpenApi(title: 'T').documentOf(app);
    var create = operationOf(doc, 'post', '/users');
    expect(create['summary'], 'Create a user');
    expect(create['operationId'], 'createUser');
  });

  test('a method without one is documented as a route', () {
    var doc = OpenApi(title: 'T').documentOf(app);
    expect(operationOf(doc, 'get', '/users/plain'), {
      'responses': {
        '200': {'description': 'OK'},
      },
    });
  });

  test('describe takes precedence over the annotation', () {
    var openApi = OpenApi(title: 'T')
      ..describe('GET', 'users/:id', OpenApiOperation(summary: 'Described'));
    var read = operationOf(openApi.documentOf(app), 'get', '/users/{id}');
    expect(read['summary'], 'Described');
  });

  test('in production, too', () async {
    var production = Angel(
      reflector: const MirrorsReflector(),
      environment: AngelEnvironment('production'),
    );
    await production.configure(UserController().configureServer);
    production.optimizeForProduction(force: true);
    var read = operationOf(
      OpenApi(title: 'T').documentOf(production),
      'get',
      '/users/{id}',
    );
    expect(read['summary'], 'Read a user');
  });
}
