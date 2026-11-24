import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_openapi/angel3_openapi.dart';
import 'package:test/test.dart';

import 'fixtures/todo.dart';

/// A service of todos, as an `OrmService<int?, Todo, TodoQuery>` is.
class TodoService extends Service<int?, Todo> {}

/// A service of nullable todos.
class MaybeTodoService extends Service<String?, Todo?> {}

/// A service of a model whose schema is not given.
class NoteService extends Service<String?, Note> {}

class Note {}

void main() {
  test('schemasOf collects the schemas of models, and of those they hold', () {
    var schemas = OpenApi.schemasOf([TodoSerializer.addJsonSchemas]);
    expect(schemas.keys.toSet(), {'Todo', 'User'});
    expect(schemas['Todo'], TodoSerializer.jsonSchema);
  });

  test('a service of a model refers to its generated schema', () {
    var openApi = OpenApi(
      title: 'T',
      schemas: OpenApi.schemasOf([TodoSerializer.addJsonSchemas]),
    )..describeService('todos', schema: OpenApi.ref(TodoSerializer.schemaName));
    var app = Angel()..use('/todos', MapService());
    var doc = openApi.documentOf(app);
    var schemas = (doc['components'] as Map)['schemas'] as Map;
    expect(schemas.keys.toSet(), {'Todo', 'User'});
    var todo = schemas['Todo'] as Map;
    expect(todo['required'], ['text']);
    expect(((todo['properties'] as Map)['owner'] as Map)['anyOf'], [
      {r'$ref': '#/components/schemas/User'},
      {'type': 'null'},
    ]);
    var create = ((doc['paths'] as Map)['/todos'] as Map)['post'] as Map;
    expect(
      ((create['requestBody'] as Map)['content'] as Map)['application/json'],
      {
        'schema': {r'$ref': '#/components/schemas/Todo'},
      },
    );
  });

  group('a service of a model of a schema given', () {
    late OpenApi openApi;
    late Map paths;

    /// The schema of the request body of the create of [path].
    Object? bodyOf(String path) {
      var create = (paths[path] as Map)['post'] as Map;
      var body = create['requestBody'] as Map?;
      return ((body?['content'] as Map?)?['application/json']
          as Map?)?['schema'];
    }

    /// The schema of the response of the read of [path].
    Object? itemOf(String path) {
      var read = (paths['$path/{id}'] as Map)['get'] as Map;
      var ok = (read['responses'] as Map)['200'] as Map;
      return ((ok['content'] as Map?)?['application/json'] as Map?)?['schema'];
    }

    setUp(() {
      openApi = OpenApi(
        title: 'T',
        schemas: OpenApi.schemasOf([TodoSerializer.addJsonSchemas]),
      );
    });

    Map pathsOf(Angel app) => paths = openApi.documentOf(app)['paths'] as Map;

    test('refers to it, without describeService', () {
      pathsOf(
        Angel()
          ..use('/todos', TodoService())
          ..use('/maybe', MaybeTodoService()),
      );
      var todo = {r'$ref': '#/components/schemas/Todo'};
      expect(bodyOf('/todos'), todo);
      expect(itemOf('/todos'), todo);
      expect(bodyOf('/maybe'), todo);
    });

    test('of the schemas of the components of extra', () {
      openApi = OpenApi(
        title: 'T',
        extra: {
          'components': {
            'schemas': {
              'Note': {'type': 'object'},
            },
          },
        },
      );
      pathsOf(Angel()..use('/notes', NoteService()));
      expect(bodyOf('/notes'), {r'$ref': '#/components/schemas/Note'});
    });

    test('is none of a model of no schema given, or of a map', () {
      pathsOf(
        Angel()
          ..use('/notes', NoteService())
          ..use('/maps', MapService()),
      );
      expect(bodyOf('/notes'), isNull);
      expect(itemOf('/notes'), isNull);
      expect(bodyOf('/maps'), isNull);
    });

    test('describeService replaces it', () {
      openApi.describeService('todos', schema: OpenApi.ref('User'));
      pathsOf(Angel()..use('/todos', TodoService()));
      expect(bodyOf('/todos'), {r'$ref': '#/components/schemas/User'});
    });
  });
}
