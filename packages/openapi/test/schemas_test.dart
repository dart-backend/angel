import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_openapi/angel3_openapi.dart';
import 'package:test/test.dart';

import 'fixtures/todo.dart';

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
}
