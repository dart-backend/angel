import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_openapi/angel3_openapi.dart';
import 'package:test/test.dart';

import 'fixtures/aot_controller.dart';

void main() {
  test('reads @OpenApiOperation of generated reflection data', () async {
    var app = Angel(
      reflector: StaticReflector.combine([aotControllerReflection]),
    );
    await app.configure(ItemController().configureServer);
    var paths = OpenApi(title: 'T').documentOf(app)['paths'] as Map;
    var read = (paths['/items/{id}'] as Map)['get'] as Map;
    expect(read['summary'], 'Read an item');
    expect((read['parameters'] as List).single['schema'], {'type': 'integer'});
  });
}
