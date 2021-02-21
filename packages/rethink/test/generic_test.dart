import 'package:angel_client/angel_client.dart' as c;
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_rethink/angel_rethink.dart';
import 'package:angel_test/angel_test.dart';
import 'package:logging/logging.dart';
import 'package:rethinkdb_dart/rethinkdb_dart.dart';
import 'package:test/test.dart';
import 'common.dart';

main() {
  Angel app;
  TestClient client;
  Rethinkdb r;
  c.Service todoService;

  setUp(() async {
    r = Rethinkdb();
    var conn = await r.connect();

    app = Angel();
    app.use('/todos', RethinkService(conn, r.table('todos')));

    app.errorHandler = (e, req, res) async {
      print('Whoops: $e');
    };

    app.logger = Logger.detached('angel')..onRecord.listen(print);

    client = await connectTo(app);
    todoService = client.service('todos');
  });

  tearDown(() => client.close());

  test('index', () async {
    var result = await todoService.index();
    print('Response: $result');
    expect(result, isList);
  });

  test('create+read', () async {
    var todo = Todo(title: 'Clean your room');
    var creation = await todoService.create(todo.toJson());
    print('Creation: $creation');

    var id = creation['id'];
    var result = await todoService.read(id);

    print('Response: $result');
    expect(result, isMap);
    expect(result['id'], equals(id));
    expect(result['title'], equals(todo.title));
    expect(result['completed'], equals(todo.completed));
  });

  test('modify', () async {
    var todo = Todo(title: 'Clean your room');
    var creation = await todoService.create(todo.toJson());
    print('Creation: $creation');

    var id = creation['id'];
    var result = await todoService.modify(id, {'title': 'Eat healthy'});

    print('Response: $result');
    expect(result, isMap);
    expect(result['id'], equals(id));
    expect(result['title'], equals('Eat healthy'));
    expect(result['completed'], equals(todo.completed));
  });

  test('remove', () async {
    var todo = Todo(title: 'Clean your room');
    var creation = await todoService.create(todo.toJson());
    print('Creation: $creation');

    var id = creation['id'];
    var result = await todoService.remove(id);

    print('Response: $result');
    expect(result, isMap);
    expect(result['id'], equals(id));
    expect(result['title'], equals(todo.title));
    expect(result['completed'], equals(todo.completed));
  });
}
